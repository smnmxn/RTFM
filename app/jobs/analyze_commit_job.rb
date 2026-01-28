require "octokit"
require "open3"
require "fileutils"
require "json"
require "timeout"

class AnalyzeCommitJob < ApplicationJob
  include DockerVolumeHelper
  include ClaudeUsageTracker
  include ToastNotifier

  queue_as :analysis

  retry_on Octokit::Error, wait: :polynomially_longer, attempts: 3

  ANALYSIS_TIMEOUT = 300

  def perform(project_id:, commit_sha:, commit_url:, commit_title:, commit_message:, baseline_sha: nil, source_repo: nil)
    project = Project.find_by(id: project_id)
    return unless project

    # Determine which repo this commit is from
    @source_repo = source_repo || project.primary_github_repo

    # Find the project repository record for this source repo
    project_repo = project.project_repositories.find_by(github_repo: @source_repo)
    client = project_repo&.client || project.github_client
    return unless client

    # Use baseline to get cumulative diff (baseline..commit), falling back to single commit diff
    @baseline_sha = baseline_sha || project.analysis_commit_sha
    if @baseline_sha.present? && @baseline_sha != commit_sha
      Rails.logger.info "[AnalyzeCommitJob] Fetching compare diff: #{@baseline_sha[0..6]}..#{commit_sha[0..6]}"
      comparison = client.compare(
        @source_repo,
        @baseline_sha,
        commit_sha,
        accept: "application/vnd.github.v3.diff"
      )
      diff = comparison
    else
      Rails.logger.info "[AnalyzeCommitJob] No baseline, fetching single commit diff for #{commit_sha[0..6]}"
      diff = client.commit(
        @source_repo,
        commit_sha,
        accept: "application/vnd.github.v3.diff"
      )
    end

    # Find existing update or create new one (supports re-analysis)
    update = project.updates.find_or_initialize_by(commit_sha: commit_sha, source_type: :commit)
    update.assign_attributes(
      title: commit_title.presence || "Commit #{commit_sha[0..6]}",
      content: "Analyzing changes...",
      social_snippet: "",
      commit_url: commit_url,
      status: :draft,
      analysis_status: "running"
    )
    update.save!

    begin
      result = run_commit_analysis(project, update, diff, commit_title, commit_message)

      if result[:success]
        # Advance the baseline BEFORE updating analysis_status, since that triggers
        # the broadcast_code_history_refresh which needs the new baseline
        project.update!(analysis_commit_sha: commit_sha, analyzed_at: Time.current)

        update.update!(
          title: result[:title].presence || update.title,
          content: result[:content],
          analysis_status: "completed",
          recommended_articles: result[:recommended_articles]
        )

        # Create Recommendation records from the articles
        create_recommendations(project, update, result[:recommended_articles])
        Rails.logger.info "[AnalyzeCommitJob] AI analysis completed for commit #{commit_sha[0..6]} in project #{project.id}, baseline advanced"
        article_titles = result[:recommended_articles]&.dig("articles")&.map { |a| a["title"] } || []
        broadcast_toast(project, message: "We've reviewed code changes from commit #{commit_sha[0..6]}", action_url: "/projects/#{project.slug}?tab=code_history", action_label: "View", event_type: "commit_analyzed", notification_metadata: { commit_sha: commit_sha, commit_title: commit_title, article_titles: article_titles })
      else
        # Fall back to placeholder content
        update.update!(
          content: placeholder_content(commit_sha, commit_title, commit_message, diff),
          analysis_status: "failed"
        )
        Rails.logger.warn "[AnalyzeCommitJob] AI analysis failed, using placeholder for commit #{commit_sha[0..6]}: #{result[:error]}"
        broadcast_toast(project, message: "We couldn't review commit #{commit_sha[0..6]}", type: "error", action_url: "/projects/#{project.slug}?tab=code_history", action_label: "View", event_type: "commit_analyzed", notification_metadata: { commit_sha: commit_sha, commit_title: commit_title })
      end
    rescue StandardError => e
      # Fall back to placeholder content on any error
      update.update!(
        content: placeholder_content(commit_sha, commit_title, commit_message, diff),
        analysis_status: "failed"
      )
      Rails.logger.error "[AnalyzeCommitJob] Error during AI analysis for commit #{commit_sha[0..6]}: #{e.message}"
      broadcast_toast(project, message: "We couldn't review this commit", type: "error", event_type: "commit_analyzed", notification_metadata: { commit_sha: commit_sha, commit_title: commit_title })
    end
  end

  private

  def run_commit_analysis(project, update, diff, commit_title, commit_message)
    input_dir = create_analysis_input_dir("commit_input_#{update.id}")
    output_dir = create_analysis_output_dir("commit_output_#{update.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write input files
      File.write(File.join(input_dir, "diff.patch"), diff.to_s)
      File.write(File.join(input_dir, "context.json"), build_context_json(project, update, commit_title, commit_message))

      # Build repos JSON for multi-repo support
      repos_json = build_repos_json(project)

      if repos_json.empty?
        # Fall back to legacy single-repo mode
        github_token = get_github_token(project)
        return { success: false, error: "No GitHub token available" } unless github_token

        cmd = [
          "docker", "run",
          "--rm",
          "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
          "-e", "GITHUB_TOKEN=#{github_token}",
          "-e", "GITHUB_REPO=#{@source_repo}",
          "-v", "#{host_volume_path(input_dir)}:/input:ro",
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          "--entrypoint", "/analyze_commit.sh",
          docker_image
        ]
        Rails.logger.info "[AnalyzeCommitJob] Running Docker commit analysis (legacy mode) for #{@source_repo} commit #{update.commit_sha[0..6]}"
      else
        # Multi-repo mode
        cmd = [
          "docker", "run",
          "--rm",
          "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
          "-e", "GITHUB_REPOS_JSON=#{repos_json.to_json}",
          "-v", "#{host_volume_path(input_dir)}:/input:ro",
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          "--entrypoint", "/analyze_commit.sh",
          docker_image
        ]
        Rails.logger.info "[AnalyzeCommitJob] Running Docker commit analysis (multi-repo mode) for #{repos_json.size} repos, commit from #{@source_repo}"
      end
      Rails.logger.debug "[AnalyzeCommitJob] Command: #{cmd.map { |c| c.include?("ANTHROPIC") ? "ANTHROPIC_API_KEY=***" : c }.join(' ')}"

      stdout, stderr, status = Timeout.timeout(ANALYSIS_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[AnalyzeCommitJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[AnalyzeCommitJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[AnalyzeCommitJob] Stderr: #{stderr[0..500]}" if stderr.present?

      # Log output files
      if Dir.exist?(output_dir)
        files = Dir.entries(output_dir) - [ ".", ".." ]
        Rails.logger.info "[AnalyzeCommitJob] Output files: #{files.join(', ')}"
      end

      # Record usage regardless of success/failure
      record_claude_usage(
        output_dir: output_dir,
        job_type: "analyze_commit",
        project: project,
        metadata: { update_id: update.id, commit_sha: update.commit_sha },
        success: status.success?,
        error_message: status.success? ? nil : stderr
      )

      if status.success?
        title = read_output_file(output_dir, "title.txt")
        content = read_output_file(output_dir, "content.md")
        articles_json = read_output_file(output_dir, "articles.json")

        Rails.logger.info "[AnalyzeCommitJob] Title: #{title}"
        Rails.logger.info "[AnalyzeCommitJob] Content length: #{content&.length || 0} chars"
        Rails.logger.info "[AnalyzeCommitJob] Articles JSON: #{articles_json}"

        if content.present?
          recommended = parse_articles_json(articles_json)
          Rails.logger.info "[AnalyzeCommitJob] Parsed recommendations: #{recommended&.dig('articles')&.size || 0} articles"
          {
            success: true,
            title: title,
            content: content,
            recommended_articles: recommended
          }
        else
          { success: false, error: "No content generated" }
        end
      else
        { success: false, error: "Docker command failed: #{stderr}" }
      end
    rescue Timeout::Error
      { success: false, error: "Analysis timed out after #{ANALYSIS_TIMEOUT} seconds" }
    ensure
      cleanup_analysis_dir(input_dir)
      cleanup_analysis_dir(output_dir)
    end
  end

  def build_context_json(project, update, commit_title, commit_message)
    context = {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      key_patterns: project.analysis_metadata&.dig("key_patterns") || [],
      commit_sha: update.commit_sha,
      commit_title: commit_title,
      commit_message: commit_message,
      source_repo: @source_repo,
      github_repo: @source_repo  # Legacy compatibility
    }

    # Include repository relationships for multi-repo projects
    if project.repository_relationships.present?
      context[:repository_relationships] = project.repository_relationships
    end

    context.to_json
  end

  def read_output_file(output_dir, filename)
    path = File.join(output_dir, filename)
    return nil unless File.exist?(path)
    content = File.read(path).strip
    content.presence
  end

  def parse_articles_json(json_string)
    return nil if json_string.blank?

    parsed = JSON.parse(json_string)
    return nil unless parsed.is_a?(Hash) && parsed.key?("articles")

    parsed
  rescue JSON::ParserError => e
    Rails.logger.warn "[AnalyzeCommitJob] Failed to parse articles JSON: #{e.message}"
    nil
  end

  def create_recommendations(project, update, articles_data)
    Rails.logger.info "[AnalyzeCommitJob] create_recommendations called with: #{articles_data.inspect}"

    if articles_data.blank?
      Rails.logger.info "[AnalyzeCommitJob] No articles_data provided, skipping recommendations"
      return
    end

    articles = articles_data["articles"]
    if articles.blank?
      Rails.logger.info "[AnalyzeCommitJob] articles_data present but no 'articles' key or empty array"
      return
    end

    # Clear any existing recommendations for this update (for re-analysis)
    update.recommendations.destroy_all

    articles.each do |article|
      Rails.logger.info "[AnalyzeCommitJob] Creating recommendation: #{article['title']}"
      Recommendation.create!(
        project: project,
        source_update: update,
        title: article["title"],
        description: article["description"],
        justification: article["justification"],
        status: :pending
      )
    end

    Rails.logger.info "[AnalyzeCommitJob] Created #{articles.size} recommendations for commit #{update.commit_sha[0..6]}"
  end

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[AnalyzeCommitJob] Building Docker image #{image_name}"

      _, stderr, status = Open3.capture3(
        "docker", "build", "-t", image_name, dockerfile_path.to_s
      )

      unless status.success?
        raise "Failed to build Docker image: #{stderr}"
      end
    end
  end

  def placeholder_content(commit_sha, title, message, diff)
    lines_changed = diff.to_s.lines.count { |line| line.start_with?("+", "-") && !line.start_with?("+++", "---") }

    <<~CONTENT
      ## #{title || "Commit #{commit_sha[0..6]}"}

      #{message.presence || "_No commit message provided._"}

      ---

      **This update was automatically generated from a commit.**

      - Commit: #{commit_sha[0..6]}
      - Lines changed: ~#{lines_changed}

      _AI analysis was unavailable. This is a placeholder summary._
    CONTENT
  end

  def build_repos_json(project)
    # Build repos array with tokens for multi-repo Docker analysis
    project.project_repositories.filter_map do |pr|
      begin
        token = GithubAppService.installation_token(pr.github_installation_id)
        {
          repo: pr.github_repo,
          directory: pr.clone_directory_name,
          token: token
        }
      rescue => e
        Rails.logger.error "[AnalyzeCommitJob] Failed to get token for repo #{pr.github_repo}: #{e.message}"
        nil
      end
    end
  end

  def get_github_token(project)
    installation = project.github_app_installation
    return nil unless installation

    GithubAppService.installation_token(installation.github_installation_id)
  rescue => e
    Rails.logger.error "[AnalyzeCommitJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

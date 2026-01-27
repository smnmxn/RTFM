require "octokit"
require "open3"
require "fileutils"
require "json"
require "timeout"

class AnalyzePullRequestJob < ApplicationJob
  include DockerVolumeHelper
  include ClaudeUsageTracker

  queue_as :analysis

  retry_on Octokit::Error, wait: :polynomially_longer, attempts: 3

  # Shorter timeout than codebase analysis (5 minutes)
  ANALYSIS_TIMEOUT = 300

  def perform(project_id:, pull_request_number:, pull_request_url:, pull_request_title:, pull_request_body:, merge_commit_sha: nil, source_repo: nil)
    project = Project.find_by(id: project_id)
    return unless project

    # Determine which repo this PR is from
    @source_repo = source_repo || project.primary_github_repo
    @merge_commit_sha = merge_commit_sha

    # Find the project repository record for this source repo
    project_repo = project.project_repositories.find_by(github_repo: @source_repo)
    client = project_repo&.client || project.github_client
    return unless client

    # Use baseline to get cumulative diff if available, otherwise use PR diff
    baseline_sha = project.analysis_commit_sha
    if baseline_sha.present? && @merge_commit_sha.present?
      Rails.logger.info "[AnalyzePullRequestJob] Fetching compare diff: #{baseline_sha[0..6]}..#{@merge_commit_sha[0..6]}"
      diff = client.compare(
        @source_repo,
        baseline_sha,
        @merge_commit_sha,
        accept: "application/vnd.github.v3.diff"
      )
    else
      Rails.logger.info "[AnalyzePullRequestJob] No baseline/merge SHA, fetching PR diff for PR ##{pull_request_number}"
      diff = client.pull_request(
        @source_repo,
        pull_request_number,
        accept: "application/vnd.github.v3.diff"
      )
    end

    # Find existing update or create new one (supports re-analysis)
    update = project.updates.find_or_initialize_by(pull_request_number: pull_request_number)
    update.assign_attributes(
      title: pull_request_title.presence || "PR ##{pull_request_number}",
      content: "Analyzing changes...",
      social_snippet: "",
      pull_request_url: pull_request_url,
      status: :draft,
      analysis_status: "running"
    )
    update.save!

    begin
      result = run_pr_analysis(project, update, diff, pull_request_title, pull_request_body)

      if result[:success]
        update.update!(
          title: result[:title].presence || update.title,
          content: result[:content],
          analysis_status: "completed",
          recommended_articles: result[:recommended_articles]
        )

        # Create Recommendation records from the articles
        create_recommendations(project, update, result[:recommended_articles])

        # Advance the baseline to this PR's merge commit if available
        if @merge_commit_sha.present?
          project.update!(analysis_commit_sha: @merge_commit_sha, analyzed_at: Time.current)
          Rails.logger.info "[AnalyzePullRequestJob] Baseline advanced to #{@merge_commit_sha[0..6]}"
        end

        Rails.logger.info "[AnalyzePullRequestJob] AI analysis completed for PR ##{pull_request_number} in project #{project.id}"
      else
        # Fall back to placeholder content
        update.update!(
          content: placeholder_content(pull_request_number, pull_request_title, pull_request_body, diff),
          analysis_status: "failed"
        )
        Rails.logger.warn "[AnalyzePullRequestJob] AI analysis failed, using placeholder for PR ##{pull_request_number}: #{result[:error]}"
      end
    rescue StandardError => e
      # Fall back to placeholder content on any error
      update.update!(
        content: placeholder_content(pull_request_number, pull_request_title, pull_request_body, diff),
        analysis_status: "failed"
      )
      Rails.logger.error "[AnalyzePullRequestJob] Error during AI analysis for PR ##{pull_request_number}: #{e.message}"
    end
  end

  private

  def run_pr_analysis(project, update, diff, pr_title, pr_body)
    input_dir = create_analysis_input_dir("pr_input_#{update.id}")
    output_dir = create_analysis_output_dir("pr_output_#{update.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write input files
      File.write(File.join(input_dir, "diff.patch"), diff.to_s)
      File.write(File.join(input_dir, "context.json"), build_context_json(project, update, pr_title, pr_body))

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
          "--entrypoint", "/analyze_pr.sh",
          docker_image
        ]
        Rails.logger.info "[AnalyzePullRequestJob] Running Docker PR analysis (legacy mode) for #{@source_repo} PR ##{update.pull_request_number}"
      else
        # Multi-repo mode - clone all repos for context
        cmd = [
          "docker", "run",
          "--rm",
          "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
          "-e", "GITHUB_REPOS_JSON=#{repos_json.to_json}",
          "-v", "#{host_volume_path(input_dir)}:/input:ro",
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          "--entrypoint", "/analyze_pr.sh",
          docker_image
        ]
        Rails.logger.info "[AnalyzePullRequestJob] Running Docker PR analysis (multi-repo mode) for #{repos_json.size} repos, PR from #{@source_repo}"
      end
      Rails.logger.debug "[AnalyzePullRequestJob] Command: #{cmd.map { |c| c.include?("ANTHROPIC") ? "ANTHROPIC_API_KEY=***" : c }.join(' ')}"

      stdout, stderr, status = Timeout.timeout(ANALYSIS_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[AnalyzePullRequestJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[AnalyzePullRequestJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[AnalyzePullRequestJob] Stderr: #{stderr[0..500]}" if stderr.present?

      # Log output files
      if Dir.exist?(output_dir)
        files = Dir.entries(output_dir) - [ ".", ".." ]
        Rails.logger.info "[AnalyzePullRequestJob] Output files: #{files.join(', ')}"
      end

      # Record usage regardless of success/failure
      record_claude_usage(
        output_dir: output_dir,
        job_type: "analyze_pr",
        project: project,
        metadata: { update_id: update.id, pull_request_number: update.pull_request_number },
        success: status.success?,
        error_message: status.success? ? nil : stderr
      )

      if status.success?
        title = read_output_file(output_dir, "title.txt")
        content = read_output_file(output_dir, "content.md")
        articles_json = read_output_file(output_dir, "articles.json")

        if content.present?
          {
            success: true,
            title: title,
            content: content,
            recommended_articles: parse_articles_json(articles_json)
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

  def build_context_json(project, update, pr_title, pr_body)
    context = {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      key_patterns: project.analysis_metadata&.dig("key_patterns") || [],
      pr_number: update.pull_request_number,
      pr_title: pr_title,
      pr_body: pr_body,
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
    # Validate structure
    return nil unless parsed.is_a?(Hash) && parsed.key?("articles")

    parsed
  rescue JSON::ParserError => e
    Rails.logger.warn "[AnalyzePullRequestJob] Failed to parse articles JSON: #{e.message}"
    nil
  end

  def create_recommendations(project, update, articles_data)
    return if articles_data.blank?

    articles = articles_data["articles"]
    return if articles.blank?

    # Clear any existing recommendations for this update (for re-analysis)
    update.recommendations.destroy_all

    articles.each do |article|
      Recommendation.create!(
        project: project,
        source_update: update,
        title: article["title"],
        description: article["description"],
        justification: article["justification"],
        status: :pending
      )
    end

    Rails.logger.info "[AnalyzePullRequestJob] Created #{articles.size} recommendations for PR ##{update.pull_request_number}"
  end

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[AnalyzePullRequestJob] Building Docker image #{image_name}"

      _, stderr, status = Open3.capture3(
        "docker", "build", "-t", image_name, dockerfile_path.to_s
      )

      unless status.success?
        raise "Failed to build Docker image: #{stderr}"
      end
    end
  end

  def placeholder_content(pr_number, title, body, diff)
    lines_changed = diff.to_s.lines.count { |line| line.start_with?("+", "-") && !line.start_with?("+++", "---") }

    <<~CONTENT
      ## #{title || "Pull Request ##{pr_number}"}

      #{body.presence || "_No description provided._"}

      ---

      **This update was automatically generated from a merged pull request.**

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
        Rails.logger.error "[AnalyzePullRequestJob] Failed to get token for repo #{pr.github_repo}: #{e.message}"
        nil
      end
    end
  end

  def get_github_token(project)
    installation = project.github_app_installation
    return nil unless installation

    GithubAppService.installation_token(installation.github_installation_id)
  rescue => e
    Rails.logger.error "[AnalyzePullRequestJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

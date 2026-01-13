require "octokit"
require "open3"
require "fileutils"
require "json"
require "timeout"

class AnalyzeCommitJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  retry_on Octokit::Error, wait: :polynomially_longer, attempts: 3

  ANALYSIS_TIMEOUT = 300

  def perform(project_id:, commit_sha:, commit_url:, commit_title:, commit_message:)
    project = Project.find_by(id: project_id)
    return unless project

    user = project.user
    return unless user&.github_token.present?

    client = build_github_client(user.github_token)

    # Fetch the commit diff
    diff = client.commit(
      project.github_repo,
      commit_sha,
      accept: "application/vnd.github.v3.diff"
    )

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

    # Broadcast initial "running" state
    broadcast_update_change(update, commit_title, commit_url)

    begin
      result = run_commit_analysis(project, update, diff, commit_title, commit_message)

      if result[:success]
        update.update!(
          title: result[:title].presence || update.title,
          content: result[:content],
          analysis_status: "completed"
        )

        # Create Recommendation records from the articles
        create_recommendations(project, update, result[:recommended_articles])

        Rails.logger.info "[AnalyzeCommitJob] AI analysis completed for commit #{commit_sha[0..6]} in project #{project.id}"
      else
        # Fall back to placeholder content
        update.update!(
          content: placeholder_content(commit_sha, commit_title, commit_message, diff),
          analysis_status: "failed"
        )
        Rails.logger.warn "[AnalyzeCommitJob] AI analysis failed, using placeholder for commit #{commit_sha[0..6]}: #{result[:error]}"
      end
    rescue StandardError => e
      # Fall back to placeholder content on any error
      update.update!(
        content: placeholder_content(commit_sha, commit_title, commit_message, diff),
        analysis_status: "failed"
      )
      Rails.logger.error "[AnalyzeCommitJob] Error during AI analysis for commit #{commit_sha[0..6]}: #{e.message}"
    end

    # Broadcast final state (completed or failed)
    broadcast_update_change(update, commit_title, commit_url)
  end

  private

  def build_github_client(access_token)
    Octokit::Client.new(access_token: access_token)
  end

  def run_commit_analysis(project, update, diff, commit_title, commit_message)
    input_dir = create_analysis_input_dir("commit_input_#{update.id}")
    output_dir = create_analysis_output_dir("commit_output_#{update.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write input files
      File.write(File.join(input_dir, "diff.patch"), diff.to_s)
      File.write(File.join(input_dir, "context.json"), build_context_json(project, update, commit_title, commit_message))

      # Run Docker with the commit analysis script
      cmd = [
        "docker", "run",
        "--rm",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-e", "GITHUB_TOKEN=#{project.user.github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/analyze_commit.sh",
        docker_image
      ]

      Rails.logger.info "[AnalyzeCommitJob] Running Docker commit analysis for #{project.github_repo} commit #{update.commit_sha[0..6]}"
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
      FileUtils.rm_rf(input_dir)
      FileUtils.rm_rf(output_dir)
    end
  end

  def build_context_json(project, update, commit_title, commit_message)
    {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      key_patterns: project.analysis_metadata&.dig("key_patterns") || [],
      commit_sha: update.commit_sha,
      commit_title: commit_title,
      commit_message: commit_message
    }.to_json
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

  def broadcast_update_change(update, commit_title, commit_url)
    project = update.project
    short_sha = update.commit_sha[0..6]

    # Update the changelog card
    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :updates ],
      target: ActionView::RecordIdentifier.dom_id(update),
      partial: "updates/card",
      locals: { update: update }
    )

    # Update the commit list row actions
    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :updates ],
      target: "commit-actions-#{short_sha}",
      partial: "updates/commit_row_actions",
      locals: {
        update: update,
        project: project,
        commit: {
          sha: update.commit_sha,
          short_sha: short_sha,
          title: commit_title,
          html_url: commit_url,
          message: commit_title
        }
      }
    )
  end
end

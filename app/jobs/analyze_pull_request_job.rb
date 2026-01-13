require "octokit"
require "open3"
require "fileutils"
require "json"
require "timeout"

class AnalyzePullRequestJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  retry_on Octokit::Error, wait: :polynomially_longer, attempts: 3

  # Shorter timeout than codebase analysis (5 minutes)
  ANALYSIS_TIMEOUT = 300

  def perform(project_id:, pull_request_number:, pull_request_url:, pull_request_title:, pull_request_body:)
    project = Project.find_by(id: project_id)
    return unless project

    user = project.user
    return unless user&.github_token.present?

    client = build_github_client(user.github_token)

    # Fetch the PR diff
    diff = client.pull_request(
      project.github_repo,
      pull_request_number,
      accept: "application/vnd.github.v3.diff"
    )

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

    # Broadcast initial "running" state
    broadcast_update_change(update, pull_request_title, pull_request_url)

    begin
      result = run_pr_analysis(project, update, diff, pull_request_title, pull_request_body)

      if result[:success]
        update.update!(
          title: result[:title].presence || update.title,
          content: result[:content],
          analysis_status: "completed"
        )

        # Create Recommendation records from the articles
        create_recommendations(project, update, result[:recommended_articles])

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

    # Broadcast final state (completed or failed)
    broadcast_update_change(update, pull_request_title, pull_request_url)
  end

  private

  def build_github_client(access_token)
    Octokit::Client.new(access_token: access_token)
  end

  def run_pr_analysis(project, update, diff, pr_title, pr_body)
    timestamp = Time.current.to_i
    input_dir = Rails.root.join("tmp", "pr_analysis", "input_#{update.id}_#{timestamp}")
    output_dir = Rails.root.join("tmp", "pr_analysis", "output_#{update.id}_#{timestamp}")

    FileUtils.mkdir_p(input_dir)
    FileUtils.mkdir_p(output_dir)
    FileUtils.chmod(0777, output_dir)

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write input files
      File.write(File.join(input_dir, "diff.patch"), diff.to_s)
      File.write(File.join(input_dir, "context.json"), build_context_json(project, update, pr_title, pr_body))

      # Run Docker with the PR analysis script
      cmd = [
        "docker", "run",
        "--rm",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-e", "GITHUB_TOKEN=#{project.user.github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/analyze_pr.sh",
        docker_image
      ]

      Rails.logger.info "[AnalyzePullRequestJob] Running Docker PR analysis for #{project.github_repo} PR ##{update.pull_request_number}"
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

  def build_context_json(project, update, pr_title, pr_body)
    {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      key_patterns: project.analysis_metadata&.dig("key_patterns") || [],
      pr_number: update.pull_request_number,
      pr_title: pr_title,
      pr_body: pr_body
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

  def broadcast_update_change(update, pr_title, pr_url)
    project = update.project

    # Update the changelog card
    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :updates ],
      target: ActionView::RecordIdentifier.dom_id(update),
      partial: "updates/card",
      locals: { update: update }
    )

    # Update the PR list row actions
    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :updates ],
      target: "pr-actions-#{update.pull_request_number}",
      partial: "updates/pr_row_actions",
      locals: {
        update: update,
        project: project,
        pr_number: update.pull_request_number,
        pr_title: pr_title,
        pr_url: pr_url
      }
    )
  end
end

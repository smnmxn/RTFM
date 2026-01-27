require "open3"
require "fileutils"
require "json"
require "timeout"

class CheckArticleUpdatesJob < ApplicationJob
  include DockerVolumeHelper
  include ClaudeUsageTracker

  queue_as :analysis

  TIMEOUT = 600 # 10 minutes

  def perform(check_id:)
    check = ArticleUpdateCheck.find_by(id: check_id)
    return unless check

    project = check.project

    begin
      check.update!(status: :running, started_at: Time.current)

      result = run_update_check(project, check)

      if result[:success]
        process_suggestions(check, result[:suggestions])
        check.update!(
          status: :completed,
          completed_at: Time.current,
          results: check.summary
        )
        Rails.logger.info "[CheckArticleUpdatesJob] Check completed for project #{project.id}, check #{check.id}"
      else
        check.update!(
          status: :failed,
          completed_at: Time.current,
          results: { error: result[:error] }
        )
        Rails.logger.warn "[CheckArticleUpdatesJob] Check failed for project #{project.id}: #{result[:error]}"
      end
    rescue StandardError => e
      check.update!(
        status: :failed,
        completed_at: Time.current,
        results: { error: e.message }
      )
      Rails.logger.error "[CheckArticleUpdatesJob] Error checking article updates for project #{project.id}: #{e.message}"
    end
  end

  private

  def run_update_check(project, check)
    input_dir = create_analysis_input_dir("update_check_input_#{check.id}")
    output_dir = create_analysis_output_dir("update_check_output_#{check.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write input files
      File.write(File.join(input_dir, "context.json"), build_context_json(project, check))
      File.write(File.join(input_dir, "articles.json"), build_articles_json(project))

      github_token = get_github_token(project)
      return { success: false, error: "No GitHub token available" } unless github_token

      # Build environment variables for repositories
      repos_json = project.repositories_for_analysis.to_json

      cmd = [
        "docker", "run",
        "--rm",
        *claude_auth_docker_args,
        "-e", "GITHUB_TOKEN=#{github_token}",
        "-e", "GITHUB_REPO=#{project.primary_github_repo}",
        "-e", "GITHUB_REPOS=#{repos_json}",
        "-e", "CLAUDE_MODEL=#{project.claude_model_id}",
        "-e", "TARGET_COMMIT=#{check.target_commit_sha}",
        "-e", "BASE_COMMIT=#{check.base_commit_sha}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/check_article_updates.sh",
        docker_image
      ]

      Rails.logger.info "[CheckArticleUpdatesJob] Running Docker update check for project #{project.id}"

      stdout, stderr, status = Timeout.timeout(TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[CheckArticleUpdatesJob] Exit status: #{status.exitstatus}"
      Rails.logger.info "[CheckArticleUpdatesJob] Stdout (last 2000 chars): #{stdout[-2000..]}" if stdout.present?
      Rails.logger.info "[CheckArticleUpdatesJob] Stderr (last 1000 chars): #{stderr[-1000..]}" if stderr.present?

      # Record usage
      record_claude_usage(
        output_dir: output_dir,
        job_type: "check_article_updates",
        project: project,
        metadata: { check_id: check.id },
        success: status.success?,
        error_message: status.success? ? nil : stderr
      )

      if status.success?
        suggestions_content = read_output_file(output_dir, "suggestions.json")

        if suggestions_content.present?
          begin
            suggestions = JSON.parse(suggestions_content)
            cleanup_analysis_dir(input_dir)
            cleanup_analysis_dir(output_dir)
            { success: true, suggestions: suggestions }
          rescue JSON::ParserError => e
            Rails.logger.warn "[CheckArticleUpdatesJob] JSON parse error: #{e.message}"
            cleanup_analysis_dir(input_dir)
            cleanup_analysis_dir(output_dir)
            { success: false, error: "Failed to parse suggestions JSON" }
          end
        else
          cleanup_analysis_dir(input_dir)
          cleanup_analysis_dir(output_dir)
          { success: false, error: "No suggestions output generated" }
        end
      else
        cleanup_analysis_dir(input_dir)
        cleanup_analysis_dir(output_dir)
        { success: false, error: "Docker command failed: #{stderr}" }
      end
    rescue Timeout::Error
      cleanup_analysis_dir(input_dir)
      cleanup_analysis_dir(output_dir)
      { success: false, error: "Check timed out after #{TIMEOUT} seconds" }
    end
  end

  def build_context_json(project, check)
    {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      target_commit: check.target_commit_sha,
      base_commit: check.base_commit_sha
    }.to_json
  end

  def build_articles_json(project)
    articles = project.articles.where(generation_status: :generation_completed).includes(:section)

    articles.map do |article|
      {
        id: article.id,
        title: article.title,
        description: article.recommendation&.description,
        section: article.section&.name,
        source_commit_sha: article.source_commit_sha,
        introduction: article.introduction,
        steps: article.steps&.map { |s| s["title"] }
      }
    end.to_json
  end

  def process_suggestions(check, suggestions)
    return unless suggestions.is_a?(Array)

    project = check.project
    articles_by_id = project.articles.index_by(&:id)

    suggestions.each do |suggestion|
      next unless suggestion.is_a?(Hash)

      suggestion_type = suggestion["type"] || suggestion["suggestion_type"]
      next unless suggestion_type.in?(%w[update_needed new_article])

      article_id = suggestion["article_id"]
      article = articles_by_id[article_id] if article_id.present?

      # For update_needed suggestions, we need a valid article
      if suggestion_type == "update_needed" && article.nil?
        Rails.logger.warn "[CheckArticleUpdatesJob] Skipping update_needed suggestion with invalid article_id: #{article_id}"
        next
      end

      check.article_update_suggestions.create!(
        article: article,
        suggestion_type: suggestion_type,
        priority: normalize_priority(suggestion["priority"]),
        reason: suggestion["reason"],
        affected_files: suggestion["affected_files"],
        suggested_changes: suggestion["suggested_changes"]
      )
    end
  end

  def normalize_priority(priority)
    case priority&.downcase
    when "critical" then :critical
    when "high" then :high
    when "medium" then :medium
    when "low" then :low
    else :medium
    end
  end

  def read_output_file(output_dir, filename)
    path = File.join(output_dir, filename)
    return nil unless File.exist?(path)
    content = File.read(path).strip
    content.presence
  end

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[CheckArticleUpdatesJob] Building Docker image #{image_name}"

      _, stderr, status = Open3.capture3(
        "docker", "build", "-t", image_name, dockerfile_path.to_s
      )

      unless status.success?
        raise "Failed to build Docker image: #{stderr}"
      end
    end
  end

  def get_github_token(project)
    installation = project.github_app_installation
    return nil unless installation

    GithubAppService.installation_token(installation.github_installation_id)
  rescue => e
    Rails.logger.error "[CheckArticleUpdatesJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

require "open3"
require "fileutils"
require "json"
require "timeout"

class GenerateArticleJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  GENERATION_TIMEOUT = 300 # 5 minutes

  def perform(article_id:)
    article = Article.find_by(id: article_id)
    return unless article

    recommendation = article.recommendation
    project = article.project
    source_update = recommendation.source_update

    begin
      result = run_article_generation(project, recommendation, source_update)

      if result[:success]
        if result[:structured_content]
          article.update!(
            structured_content: result[:structured_content],
            content: generate_markdown_from_structured(result[:structured_content]),
            generation_status: :generation_completed
          )
        else
          article.update!(
            content: result[:content],
            generation_status: :generation_completed
          )
        end
        Rails.logger.info "[GenerateArticleJob] Article generation completed for article #{article.id}"
      else
        article.update!(
          content: placeholder_content(recommendation),
          generation_status: :generation_failed
        )
        Rails.logger.warn "[GenerateArticleJob] Article generation failed for article #{article.id}: #{result[:error]}"
      end
    rescue StandardError => e
      article.update!(
        content: placeholder_content(recommendation),
        generation_status: :generation_failed
      )
      Rails.logger.error "[GenerateArticleJob] Error generating article #{article.id}: #{e.message}"
    end
  end

  private

  def run_article_generation(project, recommendation, source_update)
    input_dir = create_analysis_input_dir("article_input_#{recommendation.id}")
    output_dir = create_analysis_output_dir("article_output_#{recommendation.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write input files
      File.write(File.join(input_dir, "context.json"), build_context_json(project, recommendation, source_update))

      # If there's a source PR, include the diff
      if source_update.present?
        diff = fetch_pr_diff(project, source_update)
        File.write(File.join(input_dir, "diff.patch"), diff.to_s) if diff.present?
      end

      github_token = get_github_token(project)
      return { success: false, error: "No GitHub token available" } unless github_token

      # Run Docker with the article generation script
      cmd = [
        "docker", "run",
        "--rm",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-e", "GITHUB_TOKEN=#{github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/generate_article.sh",
        docker_image
      ]

      Rails.logger.info "[GenerateArticleJob] Running Docker article generation for recommendation #{recommendation.id}"

      stdout, stderr, status = Timeout.timeout(GENERATION_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[GenerateArticleJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[GenerateArticleJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[GenerateArticleJob] Stderr: #{stderr[0..500]}" if stderr.present?

      if status.success?
        json_content = read_output_file(output_dir, "article.json")

        if json_content.present?
          cleaned = extract_json(json_content)
          begin
            parsed = JSON.parse(cleaned)
            if parsed.is_a?(Hash) && (parsed["introduction"] || parsed["steps"])
              { success: true, structured_content: parsed }
            else
              Rails.logger.warn "[GenerateArticleJob] JSON missing expected structure"
              { success: true, content: json_content }
            end
          rescue JSON::ParserError => e
            Rails.logger.warn "[GenerateArticleJob] JSON parse error: #{e.message}, falling back to raw content"
            { success: true, content: json_content }
          end
        else
          { success: false, error: "No content generated" }
        end
      else
        { success: false, error: "Docker command failed: #{stderr}" }
      end
    rescue Timeout::Error
      { success: false, error: "Generation timed out after #{GENERATION_TIMEOUT} seconds" }
    ensure
      FileUtils.rm_rf(input_dir)
      FileUtils.rm_rf(output_dir)
    end
  end

  def build_context_json(project, recommendation, source_update)
    context = {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      article_title: recommendation.title,
      article_description: recommendation.description,
      article_justification: recommendation.justification
    }

    if source_update.present?
      context[:source_pr_number] = source_update.pull_request_number
      context[:source_pr_title] = source_update.title
      context[:source_pr_content] = source_update.content
    end

    context.to_json
  end

  def fetch_pr_diff(project, source_update)
    token = get_github_token(project)
    return nil unless token.present?

    client = Octokit::Client.new(access_token: token)
    client.pull_request(
      project.github_repo,
      source_update.pull_request_number,
      accept: "application/vnd.github.v3.diff"
    )
  rescue Octokit::Error => e
    Rails.logger.warn "[GenerateArticleJob] Could not fetch PR diff: #{e.message}"
    nil
  end

  def read_output_file(output_dir, filename)
    path = File.join(output_dir, filename)
    return nil unless File.exist?(path)
    content = File.read(path).strip
    content.presence
  end

  def extract_json(raw_content)
    content = raw_content.strip

    # Remove markdown code fences if present
    if content.start_with?("```")
      content = content.sub(/\A```(?:json)?\s*\n?/, "")
      content = content.sub(/\n?```\s*\z/, "")
    end

    # Try to find JSON object in content
    if (match = content.match(/\{[\s\S]*\}/))
      match[0]
    else
      content
    end
  end

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[GenerateArticleJob] Building Docker image #{image_name}"

      _, stderr, status = Open3.capture3(
        "docker", "build", "-t", image_name, dockerfile_path.to_s
      )

      unless status.success?
        raise "Failed to build Docker image: #{stderr}"
      end
    end
  end

  def placeholder_content(recommendation)
    <<~CONTENT
      # #{recommendation.title}

      _Article generation failed. Please try again._

      ## What this article should cover

      #{recommendation.description}

      ## Why this article is needed

      #{recommendation.justification}
    CONTENT
  end

  def generate_markdown_from_structured(structured)
    markdown = []

    if structured["introduction"].present?
      markdown << structured["introduction"]
      markdown << ""
    end

    if structured["prerequisites"].present? && structured["prerequisites"].any?
      markdown << "## Prerequisites"
      markdown << ""
      structured["prerequisites"].each do |prereq|
        markdown << "- #{prereq}"
      end
      markdown << ""
    end

    if structured["steps"].present? && structured["steps"].any?
      markdown << "## Steps"
      markdown << ""
      structured["steps"].each_with_index do |step, index|
        markdown << "### #{index + 1}. #{step['title']}"
        markdown << ""
        markdown << step["content"]
        markdown << ""
      end
    end

    if structured["tips"].present? && structured["tips"].any?
      markdown << "## Tips"
      markdown << ""
      structured["tips"].each do |tip|
        markdown << "- #{tip}"
      end
      markdown << ""
    end

    if structured["summary"].present?
      markdown << "---"
      markdown << ""
      markdown << structured["summary"]
    end

    markdown.join("\n")
  end

  def get_github_token(project)
    installation = project.github_app_installation
    return nil unless installation

    GithubAppService.installation_token(installation.github_installation_id)
  rescue => e
    Rails.logger.error "[GenerateArticleJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

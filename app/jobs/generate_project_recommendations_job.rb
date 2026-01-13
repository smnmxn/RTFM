require "open3"
require "fileutils"
require "json"
require "timeout"

class GenerateProjectRecommendationsJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  GENERATION_TIMEOUT = 300 # 5 minutes

  def perform(project_id:)
    project = Project.find_by(id: project_id)
    return unless project

    begin
      result = run_recommendations_generation(project)

      if result[:success]
        create_recommendations(project, result[:recommendations])
        Rails.logger.info "[GenerateProjectRecommendationsJob] Generated #{result[:recommendations]&.size || 0} recommendations for project #{project.id}"
      else
        Rails.logger.warn "[GenerateProjectRecommendationsJob] Generation failed for project #{project.id}: #{result[:error]}"
      end
    rescue StandardError => e
      Rails.logger.error "[GenerateProjectRecommendationsJob] Error for project #{project.id}: #{e.message}"
    end
  end

  private

  def run_recommendations_generation(project)
    timestamp = Time.current.to_i
    input_dir = Rails.root.join("tmp", "project_recommendations", "input_#{project.id}_#{timestamp}")
    output_dir = Rails.root.join("tmp", "project_recommendations", "output_#{project.id}_#{timestamp}")

    FileUtils.mkdir_p(input_dir)
    FileUtils.mkdir_p(output_dir)
    FileUtils.chmod(0777, output_dir)

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Write context file with project info and existing updates
      File.write(File.join(input_dir, "context.json"), build_context_json(project))

      cmd = [
        "docker", "run",
        "--rm",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-e", "GITHUB_TOKEN=#{project.user.github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/generate_project_recommendations.sh",
        docker_image
      ]

      Rails.logger.info "[GenerateProjectRecommendationsJob] Running Docker for project #{project.id}"

      stdout, stderr, status = Timeout.timeout(GENERATION_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[GenerateProjectRecommendationsJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[GenerateProjectRecommendationsJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[GenerateProjectRecommendationsJob] Stderr: #{stderr[0..500]}" if stderr.present?

      if status.success?
        json_content = read_output_file(output_dir, "recommendations.json")
        if json_content.present?
          cleaned = extract_json(json_content)
          parsed = JSON.parse(cleaned)
          { success: true, recommendations: parsed["articles"] || [] }
        else
          { success: false, error: "No output generated" }
        end
      else
        { success: false, error: "Docker command failed: #{stderr}" }
      end
    rescue Timeout::Error
      { success: false, error: "Generation timed out after #{GENERATION_TIMEOUT} seconds" }
    rescue JSON::ParserError => e
      Rails.logger.warn "[GenerateProjectRecommendationsJob] JSON parse error: #{e.message}"
      { success: false, error: "Failed to parse recommendations JSON" }
    ensure
      FileUtils.rm_rf(input_dir)
      FileUtils.rm_rf(output_dir)
    end
  end

  def build_context_json(project)
    # Include existing changelog entries so AI knows what features exist
    existing_changelogs = project.updates.order(created_at: :desc).limit(20).map do |update|
      { title: update.title, content: update.content&.truncate(500) }
    end

    # Include existing recommendations to avoid duplicates
    existing_recommendations = project.recommendations.where(status: [ :pending, :generated ]).pluck(:title)

    {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      key_patterns: project.analysis_metadata&.dig("key_patterns") || [],
      components: project.analysis_metadata&.dig("components") || [],
      existing_changelogs: existing_changelogs,
      existing_recommendation_titles: existing_recommendations
    }.to_json
  end

  def read_output_file(output_dir, filename)
    path = File.join(output_dir, filename)
    return nil unless File.exist?(path)
    File.read(path).strip.presence
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

  def create_recommendations(project, recommendations)
    return if recommendations.blank?

    recommendations.each do |rec|
      Recommendation.create!(
        project: project,
        source_update: nil, # Project-wide, not tied to a PR
        title: rec["title"],
        description: rec["description"],
        justification: rec["justification"],
        status: :pending
      )
    end
  end

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[GenerateProjectRecommendationsJob] Building Docker image #{image_name}"

      _, stderr, status = Open3.capture3(
        "docker", "build", "-t", image_name, dockerfile_path.to_s
      )

      unless status.success?
        raise "Failed to build Docker image: #{stderr}"
      end
    end
  end
end

require "open3"
require "fileutils"
require "json"
require "timeout"

# Generates recommendations for a SINGLE section.
#
# NOTE: This job is NOT used during onboarding. During onboarding, we use
# GenerateAllRecommendationsJob instead, which generates recommendations for
# ALL accepted sections in a single Claude session. This prevents duplicate
# recommendations across sections because Claude can see all sections at once.
#
# This job is still used for:
# - Custom sections added after onboarding (via SectionsController#create)
# - Manual "regenerate" triggers on individual sections
#   (via SectionsController#generate_recommendations)
class GenerateSectionRecommendationsJob < ApplicationJob
  include DockerVolumeHelper
  include ClaudeUsageTracker
  include ToastNotifier

  queue_as :analysis

  GENERATION_TIMEOUT = 300 # 5 minutes

  def perform(project_id:, section_id:)
    project = Project.find_by(id: project_id)
    section = Section.find_by(id: section_id)
    return unless project && section

    # Mark section as generating (if not already set by controller)
    if section.recommendations_status.nil?
      section.update!(
        recommendations_status: "running",
        recommendations_started_at: Time.current
      )
    end

    begin
      result = run_recommendations_generation(project, section)

      # Re-check that project/section still exist before creating recommendations
      return unless Project.exists?(project_id) && Section.exists?(section_id)

      if result[:success]
        create_recommendations(project, section, result[:recommendations])
        section.reload.update!(recommendations_status: "completed")
        Rails.logger.info "[GenerateSectionRecommendationsJob] Generated #{result[:recommendations]&.size || 0} recommendations for section #{section.id}"
        broadcast_toast(project, message: "New article ideas for #{section.name}", action_url: "/projects/#{project.slug}?tab=inbox", action_label: "View", event_type: "recommendations_generated", notification_metadata: { section_name: section.name, recommendation_count: result[:recommendations]&.size || 0 })
      else
        section.reload.update!(recommendations_status: "failed")
        Rails.logger.warn "[GenerateSectionRecommendationsJob] Generation failed for section #{section.id}: #{result[:error]}"
        broadcast_toast(project, message: "We couldn't generate recommendations for #{section.name}", type: "error", event_type: "recommendations_generated")
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey => e
      # Project or section was deleted while job was running - this is expected, just log and exit
      Rails.logger.info "[GenerateSectionRecommendationsJob] Project or section deleted during job execution: #{e.message}"
    rescue StandardError => e
      begin
        section.reload.update!(recommendations_status: "failed")
      rescue ActiveRecord::RecordNotFound
        # Section was deleted, nothing to update
      end
      Rails.logger.error "[GenerateSectionRecommendationsJob] Error for section #{section_id}: #{e.message}"
    end
  end

  private

  def run_recommendations_generation(project, section)
    input_dir = create_analysis_input_dir("section_recs_input_#{section.id}")
    output_dir = create_analysis_output_dir("section_recs_output_#{section.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      File.write(File.join(input_dir, "context.json"), build_context_json(project, section))

      github_token = get_github_token(project)
      return { success: false, error: "No GitHub token available" } unless github_token

      cmd = [
        "docker", "run",
        "--rm",
        *claude_auth_docker_args,
        "-e", "GITHUB_TOKEN=#{github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/generate_section_recommendations.sh",
        docker_image
      ]

      Rails.logger.info "[GenerateSectionRecommendationsJob] Running Docker for section #{section.id} (#{section.name})"

      stdout, stderr, status = Timeout.timeout(GENERATION_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[GenerateSectionRecommendationsJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[GenerateSectionRecommendationsJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[GenerateSectionRecommendationsJob] Stderr: #{stderr[0..500]}" if stderr.present?

      # Record usage regardless of success/failure
      record_claude_usage(
        output_dir: output_dir,
        job_type: "generate_section_recommendations",
        project: project,
        metadata: { section_id: section.id, section_slug: section.slug },
        success: status.success?,
        error_message: status.success? ? nil : stderr
      )

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
      Rails.logger.warn "[GenerateSectionRecommendationsJob] JSON parse error: #{e.message}"
      { success: false, error: "Failed to parse recommendations JSON" }
    ensure
      cleanup_analysis_dir(input_dir)
      cleanup_analysis_dir(output_dir)
    end
  end

  def build_context_json(project, section)
    # Get ALL existing article titles across ALL sections to avoid duplicates
    all_existing_articles = project.articles.pluck(:title)
    all_existing_recommendations = project.recommendations
      .where(status: [ :pending, :generated ])
      .pluck(:title)
    user_context = project.user_context || {}

    {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      key_patterns: project.analysis_metadata&.dig("key_patterns") || [],
      components: project.analysis_metadata&.dig("components") || [],
      target_users: project.analysis_metadata&.dig("target_users") || [],
      all_sections: project.sections.accepted.ordered.map { |s|
        { name: s.name, slug: s.slug, description: s.description }
      },
      section_name: section.name,
      section_slug: section.slug,
      section_description: section.description,
      existing_article_titles: all_existing_articles,
      existing_recommendation_titles: all_existing_recommendations,
      # User-provided context from onboarding questions
      user_context: user_context,
      target_audience: user_context["target_audience"],
      industry: user_context["industry"],
      documentation_goals: user_context["documentation_goals"] || [],
      tone_preference: user_context["tone_preference"],
      product_stage: user_context["product_stage"],
      # Contextual answers from sections step
      contextual_answers: user_context["contextual_answers"] || {}
    }.to_json
  end

  def create_recommendations(project, section, recommendations)
    return if recommendations.blank?

    recommendations.each do |rec|
      Recommendation.create!(
        project: project,
        section: section,
        source_update: nil,
        title: rec["title"],
        description: rec["description"],
        justification: rec["justification"],
        status: :pending
      )
    end
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

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[GenerateSectionRecommendationsJob] Building Docker image #{image_name}"

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
    Rails.logger.error "[GenerateSectionRecommendationsJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

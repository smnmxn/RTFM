require "open3"
require "fileutils"
require "json"
require "timeout"

# Generates recommendations for ALL accepted sections in a single Claude session.
# This prevents duplicate recommendations across sections because Claude can see
# all sections at once and intelligently assign each recommendation to exactly one section.
#
# Used during onboarding when user clicks "Complete" on the sections step.
# For post-onboarding custom sections, use GenerateSectionRecommendationsJob instead.
class GenerateAllRecommendationsJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  GENERATION_TIMEOUT = 600 # 10 minutes (longer since we're generating for multiple sections)

  def perform(project_id:)
    project = Project.find_by(id: project_id)
    return unless project

    accepted_sections = project.sections.accepted.ordered
    return if accepted_sections.empty?

    # Build a map of section slugs to section records for later lookup
    sections_by_slug = accepted_sections.index_by(&:slug)

    begin
      result = run_recommendations_generation(project, accepted_sections)

      # Re-check that project still exists before creating recommendations
      return unless Project.exists?(project_id)

      if result[:success]
        create_recommendations_for_all_sections(project, sections_by_slug, result[:recommendations])

        # Mark all sections as completed
        accepted_sections.each do |section|
          section.reload.update!(recommendations_status: "completed") if Section.exists?(section.id)
        end

        # Complete onboarding now that recommendations are generated
        # This triggers a broadcast that refreshes the generating page, which then redirects
        project.reload.complete_onboarding! if project.in_onboarding?

        total_count = result[:recommendations].values.flatten.size
        Rails.logger.info "[GenerateAllRecommendationsJob] Generated #{total_count} recommendations across #{accepted_sections.size} sections for project #{project.id}"
      else
        # Mark all sections as failed
        accepted_sections.each do |section|
          section.reload.update!(recommendations_status: "failed") if Section.exists?(section.id)
        end

        # Complete onboarding even on failure so user isn't stuck
        project.reload.complete_onboarding! if project.in_onboarding?

        Rails.logger.warn "[GenerateAllRecommendationsJob] Generation failed for project #{project.id}: #{result[:error]}"
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::InvalidForeignKey => e
      Rails.logger.info "[GenerateAllRecommendationsJob] Project or sections deleted during job execution: #{e.message}"
    rescue StandardError => e
      # Mark all sections as failed
      accepted_sections.each do |section|
        begin
          section.reload.update!(recommendations_status: "failed")
        rescue ActiveRecord::RecordNotFound
          # Section was deleted, nothing to update
        end
      end
      Rails.logger.error "[GenerateAllRecommendationsJob] Error for project #{project_id}: #{e.message}"
    end
  end

  private

  def run_recommendations_generation(project, accepted_sections)
    input_dir = create_analysis_input_dir("all_recs_input_#{project.id}")
    output_dir = create_analysis_output_dir("all_recs_output_#{project.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      File.write(File.join(input_dir, "context.json"), build_context_json(project, accepted_sections))

      github_token = get_github_token(project)
      return { success: false, error: "No GitHub token available" } unless github_token

      cmd = [
        "docker", "run",
        "--rm",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-e", "GITHUB_TOKEN=#{github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-v", "#{host_volume_path(input_dir)}:/input:ro",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/generate_all_recommendations.sh",
        docker_image
      ]

      Rails.logger.info "[GenerateAllRecommendationsJob] Running Docker for project #{project.id} with #{accepted_sections.size} sections"

      stdout, stderr, status = Timeout.timeout(GENERATION_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[GenerateAllRecommendationsJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[GenerateAllRecommendationsJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[GenerateAllRecommendationsJob] Stderr: #{stderr[0..500]}" if stderr.present?

      if status.success?
        json_content = read_output_file(output_dir, "recommendations.json")
        if json_content.present?
          cleaned = extract_json(json_content)
          parsed = JSON.parse(cleaned)
          # Output is already grouped by section slug
          { success: true, recommendations: parsed }
        else
          { success: false, error: "No output generated" }
        end
      else
        { success: false, error: "Docker command failed: #{stderr}" }
      end
    rescue Timeout::Error
      { success: false, error: "Generation timed out after #{GENERATION_TIMEOUT} seconds" }
    rescue JSON::ParserError => e
      Rails.logger.warn "[GenerateAllRecommendationsJob] JSON parse error: #{e.message}"
      { success: false, error: "Failed to parse recommendations JSON" }
    ensure
      cleanup_analysis_dir(input_dir)
      cleanup_analysis_dir(output_dir)
    end
  end

  def build_context_json(project, accepted_sections)
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
      # All accepted sections to generate recommendations for
      sections: accepted_sections.map { |s|
        { name: s.name, slug: s.slug, description: s.description }
      },
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

  def create_recommendations_for_all_sections(project, sections_by_slug, recommendations_by_slug)
    return if recommendations_by_slug.blank?

    recommendations_by_slug.each do |slug, recommendations|
      section = sections_by_slug[slug]
      next unless section # Skip if section slug doesn't match any accepted section

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
      Rails.logger.info "[GenerateAllRecommendationsJob] Building Docker image #{image_name}"

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
    Rails.logger.error "[GenerateAllRecommendationsJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

require "open3"
require "fileutils"
require "json"
require "timeout"

class GenerateArticleJob < ApplicationJob
  include DockerVolumeHelper
  include ClaudeUsageTracker
  include ToastNotifier

  queue_as :analysis

  GENERATION_TIMEOUT = 600 # 10 minutes

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
          update_attrs = {
            structured_content: result[:structured_content],
            content: generate_markdown_from_structured(result[:structured_content]),
            generation_status: :generation_completed,
            regeneration_guidance: nil  # Clear guidance after successful generation
          }
          update_attrs[:source_commit_sha] = result[:commit_sha] if result[:commit_sha].present?
          article.update!(update_attrs)

          # Attach generated images to StepImage records
          if result[:generated_images].present?
            attach_generated_images(article, result[:generated_images])
          end

          # Cleanup directories after images are attached
          cleanup_analysis_dir(result[:input_dir])
          cleanup_analysis_dir(result[:output_dir])
        else
          update_attrs = {
            content: result[:content],
            generation_status: :generation_completed,
            regeneration_guidance: nil  # Clear guidance after successful generation
          }
          update_attrs[:source_commit_sha] = result[:commit_sha] if result[:commit_sha].present?
          article.update!(update_attrs)
        end
        Rails.logger.info "[GenerateArticleJob] Article generation completed for article #{article.id}"
        broadcast_toast(project, message: "Article ready: #{article.title}", action_url: "/projects/#{project.slug}?tab=inbox&selected=article_#{article.id}", action_label: "View")
      else
        article.update!(
          content: placeholder_content(recommendation),
          generation_status: :generation_failed
        )
        Rails.logger.warn "[GenerateArticleJob] Article generation failed for article #{article.id}: #{result[:error]}"
        broadcast_toast(project, message: "Article generation failed: #{article.title}", type: "error", action_url: "/projects/#{project.slug}?tab=inbox&selected=article_#{article.id}", action_label: "View")
      end
    rescue StandardError => e
      article.update!(
        content: placeholder_content(recommendation),
        generation_status: :generation_failed
      )
      Rails.logger.error "[GenerateArticleJob] Error generating article #{article.id}: #{e.message}"
      broadcast_toast(project, message: "Article generation failed: #{article.title}", type: "error")
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

      # Write style context from stored project analysis
      if project.analysis_metadata&.dig("style_context").present?
        File.write(
          File.join(input_dir, "style_context.json"),
          project.analysis_metadata["style_context"].to_json
        )
        Rails.logger.info "[GenerateArticleJob] Wrote style_context.json from stored analysis"
      else
        Rails.logger.warn "[GenerateArticleJob] No style_context found in project analysis_metadata"
      end

      # Write compiled CSS for accurate mockup generation
      if project.analysis_metadata&.dig("compiled_css").present?
        File.write(
          File.join(input_dir, "compiled_css.txt"),
          project.analysis_metadata["compiled_css"]
        )
        Rails.logger.info "[GenerateArticleJob] Wrote compiled_css.txt (#{project.analysis_metadata['compiled_css'].length} bytes)"
      else
        # Write empty file so the script knows there's no compiled CSS
        File.write(File.join(input_dir, "compiled_css.txt"), "")
        Rails.logger.info "[GenerateArticleJob] No compiled CSS available - mockups will use style context fallback"
      end

      # If there's a source PR, include the diff
      if source_update.present?
        diff = fetch_pr_diff(project, source_update)
        File.write(File.join(input_dir, "diff.patch"), diff.to_s) if diff.present?
      end

      # Write existing articles for context
      current_article = recommendation.article
      write_existing_articles_corpus(input_dir, project, current_article) if current_article

      github_token = get_github_token(project)
      return { success: false, error: "No GitHub token available" } unless github_token

      # Run Docker with the article generation script
      cmd = [
        "docker", "run",
        "--rm",
        *claude_auth_docker_args,
        "-e", "GITHUB_TOKEN=#{github_token}",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-e", "CLAUDE_MODEL=#{project.claude_model_id}",
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
      Rails.logger.info "[GenerateArticleJob] Stdout (last 2000 chars): #{stdout[-2000..]}" if stdout.present?
      Rails.logger.info "[GenerateArticleJob] Stderr (last 1000 chars): #{stderr[-1000..]}" if stderr.present?

      # Log output directory contents
      if Dir.exist?(output_dir)
        files = Dir.glob(File.join(output_dir, "**/*")).select { |f| File.file?(f) }
        Rails.logger.info "[GenerateArticleJob] Output files: #{files.map { |f| "#{f.sub(output_dir + '/', '')} (#{File.size(f)} bytes)" }.join(', ')}"
      end

      # Record usage regardless of success/failure
      record_claude_usage(
        output_dir: output_dir,
        job_type: "generate_article",
        project: project,
        metadata: { article_id: recommendation.article&.id, recommendation_id: recommendation.id },
        success: status.success?,
        error_message: status.success? ? nil : stderr
      )

      if status.success?
        json_content = read_output_file(output_dir, "article.json")
        commit_sha = read_output_file(output_dir, "commit_sha.txt")
        # Log usage.json for debugging
      usage_content = read_output_file(output_dir, "usage.json")
      Rails.logger.info "[GenerateArticleJob] usage.json: #{usage_content}"

      # Log raw Claude output if available
      raw_output = read_output_file(output_dir, "claude_raw_output.json")
      Rails.logger.info "[GenerateArticleJob] claude_raw_output.json (first 2000 chars): #{raw_output&.slice(0, 2000)}" if raw_output

      Rails.logger.info "[GenerateArticleJob] article.json content (first 500 chars): #{json_content&.slice(0, 500).inspect}"

        if json_content.present?
          cleaned = extract_json(json_content)
          begin
            parsed = JSON.parse(cleaned)
            if parsed.is_a?(Hash) && (parsed["introduction"] || parsed["steps"])
              generated_images = collect_generated_images(output_dir, parsed)
              {
                success: true,
                structured_content: parsed,
                generated_images: generated_images,
                commit_sha: commit_sha,
                input_dir: input_dir,
                output_dir: output_dir
              }
            else
              Rails.logger.warn "[GenerateArticleJob] JSON missing expected structure — treating as failure. Content preview: #{json_content&.slice(0, 200).inspect}"
              cleanup_analysis_dir(input_dir)
              cleanup_analysis_dir(output_dir)
              { success: false, error: "Claude returned narrative text instead of structured JSON" }
            end
          rescue JSON::ParserError => e
            Rails.logger.warn "[GenerateArticleJob] JSON parse error: #{e.message} — treating as failure. Content preview: #{json_content&.slice(0, 200).inspect}"
            cleanup_analysis_dir(input_dir)
            cleanup_analysis_dir(output_dir)
            { success: false, error: "Claude output was not valid JSON: #{e.message}" }
          end
        else
          cleanup_analysis_dir(input_dir)
          cleanup_analysis_dir(output_dir)
          { success: false, error: "No content generated" }
        end
      else
        cleanup_analysis_dir(input_dir)
        cleanup_analysis_dir(output_dir)
        { success: false, error: "Docker command failed: #{stderr}" }
      end
    rescue Timeout::Error
      cleanup_analysis_dir(input_dir)
      cleanup_analysis_dir(output_dir)
      { success: false, error: "Generation timed out after #{GENERATION_TIMEOUT} seconds" }
    end
  end

  def collect_generated_images(output_dir, structured_content)
    images_dir = File.join(output_dir, "images")
    return {} unless Dir.exist?(images_dir)

    images = {}
    steps = structured_content["steps"] || []

    steps.each_with_index do |step, index|
      image_path = File.join(images_dir, "step_#{index}.png")
      if File.exist?(image_path)
        # Attach any image that exists, regardless of has_image flag
        # Claude sometimes renders images but forgets to set has_image: true
        images[index] = image_path
        if step["has_image"]
          Rails.logger.info "[GenerateArticleJob] Found generated image for step #{index}: #{image_path}"
        else
          Rails.logger.warn "[GenerateArticleJob] Found image for step #{index} (has_image was false, attaching anyway): #{image_path}"
        end
      end
    end

    Rails.logger.info "[GenerateArticleJob] Collected #{images.size} generated images"
    images
  end

  def attach_generated_images(article, generated_images)
    return if generated_images.blank?

    generated_images.each do |step_index, image_path|
      next unless File.exist?(image_path)

      begin
        step_image = article.step_images.find_or_initialize_by(step_index: step_index)

        # Read diagnostics JSON if available
        diagnostics_path = image_path.sub(".png", "_diagnostics.json")
        diagnostics = if File.exist?(diagnostics_path)
          begin
            JSON.parse(File.read(diagnostics_path))
          rescue JSON::ParserError => e
            Rails.logger.warn "[GenerateArticleJob] Failed to parse diagnostics for step #{step_index}: #{e.message}"
            nil
          end
        end

        # Read source HTML if available
        output_dir = File.dirname(File.dirname(image_path))
        html_path = File.join(output_dir, "html", "step_#{step_index}.html")
        source_html = File.exist?(html_path) ? File.read(html_path) : nil

        # Determine render status from diagnostics
        render_status = determine_render_status(diagnostics)

        # Read file content into memory to avoid closed stream issues
        image_data = File.binread(image_path)

        step_image.assign_attributes(
          render_metadata: diagnostics,
          render_status: render_status,
          render_attempts: (step_image.render_attempts || 0) + 1,
          source_html: source_html
        )

        step_image.image.attach(
          io: StringIO.new(image_data),
          filename: "step_#{step_index}.png",
          content_type: "image/png"
        )

        step_image.save!

        if render_status == StepImage::RENDER_STATUS_WARNING
          Rails.logger.warn "[GenerateArticleJob] Mockup for step #{step_index} has quality warnings (score: #{diagnostics&.dig('qualityScore', 'score')})"
        elsif render_status == StepImage::RENDER_STATUS_FAILED
          Rails.logger.error "[GenerateArticleJob] Mockup for step #{step_index} failed quality checks"
        else
          Rails.logger.info "[GenerateArticleJob] Attached generated image to step #{step_index} for article #{article.id}"
        end
      rescue => e
        Rails.logger.error "[GenerateArticleJob] Failed to attach image for step #{step_index}: #{e.message}"
      end
    end
  end

  def determine_render_status(diagnostics)
    return StepImage::RENDER_STATUS_PENDING unless diagnostics

    quality_rating = diagnostics.dig("qualityScore", "rating")
    is_likely_blank = diagnostics.dig("metrics", "isLikelyBlank")
    page_errors = diagnostics["pageErrors"] || []
    failed_resources = diagnostics["failedResources"] || []

    if is_likely_blank || quality_rating == "poor"
      StepImage::RENDER_STATUS_FAILED
    elsif quality_rating == "acceptable" || page_errors.any? || failed_resources.length > 2
      StepImage::RENDER_STATUS_WARNING
    else
      StepImage::RENDER_STATUS_SUCCESS
    end
  end

  def build_context_json(project, recommendation, source_update)
    article = recommendation.article

    context = {
      project_name: project.name,
      project_overview: project.project_overview,
      analysis_summary: project.analysis_summary,
      tech_stack: project.analysis_metadata&.dig("tech_stack") || [],
      article_title: recommendation.title,
      article_description: recommendation.description,
      article_justification: recommendation.justification
    }

    # Include regeneration guidance if present (user-provided instructions for improvement)
    if article&.regeneration_guidance.present?
      context[:regeneration_guidance] = article.regeneration_guidance
    end

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

  def write_existing_articles_corpus(input_dir, project, current_article)
    # Get completed articles (exclude the one being generated)
    completed_articles = project.articles
      .where(generation_status: :generation_completed)
      .where.not(id: current_article.id)
      .includes(:section, :step_images)

    return if completed_articles.empty?

    # Create the directory structure
    articles_dir = File.join(input_dir, "existing_articles")
    FileUtils.mkdir_p(articles_dir)

    # Build manifest with metadata
    manifest = {
      total_count: completed_articles.count,
      articles: []
    }

    completed_articles.find_each do |article|
      article_slug = article.slug
      article_path = File.join(articles_dir, article_slug)
      FileUtils.mkdir_p(article_path)

      # Write structured content
      if article.structured_content.present?
        File.write(
          File.join(article_path, "content.json"),
          article.structured_content.to_json
        )
      end

      # Write step HTML files (only if source_html is populated)
      images_with_html = article.step_images.select { |si| si.source_html.present? }
      if images_with_html.any?
        images_dir = File.join(article_path, "images")
        FileUtils.mkdir_p(images_dir)

        images_with_html.each do |step_image|
          File.write(
            File.join(images_dir, "step_#{step_image.step_index}.html"),
            step_image.source_html
          )
        end
      end

      # Add to manifest
      manifest[:articles] << {
        slug: article_slug,
        title: article.title,
        section: article.section&.name,
        step_count: article.structured_content&.dig("steps")&.count || 0,
        image_count: images_with_html.count
      }
    end

    # Write manifest
    File.write(
      File.join(articles_dir, "manifest.json"),
      JSON.pretty_generate(manifest)
    )

    Rails.logger.info "[GenerateArticleJob] Wrote #{manifest[:total_count]} existing articles to corpus"
  end
end

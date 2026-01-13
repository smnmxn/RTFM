require "open3"
require "fileutils"
require "json"
require "timeout"

class AnalyzeCodebaseJob < ApplicationJob
  queue_as :analysis

  # Longer timeout for analysis (10 minutes)
  ANALYSIS_TIMEOUT = 600

  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project

    user = project.user
    return unless user&.github_token.present?

    project.update!(analysis_status: "running")

    begin
      result = run_analysis(project, user)

      if result[:success]
        project.update!(
          analysis_summary: result[:summary],
          analysis_metadata: result[:metadata],
          analysis_status: "completed",
          analyzed_at: Time.current,
          analysis_commit_sha: result[:commit_sha],
          project_overview: result[:overview],
          contextual_questions: result[:contextual_questions]
        )
        Rails.logger.info "[AnalyzeCodebaseJob] Analysis completed for project #{project.id}"
        if result[:contextual_questions].present?
          Rails.logger.info "[AnalyzeCodebaseJob] Generated #{result[:contextual_questions].size} contextual questions"
        end

        # Trigger section suggestions after successful analysis
        SuggestSectionsJob.perform_later(project_id: project.id)

        # Auto-advance onboarding if in wizard
        if project.in_onboarding? && project.onboarding_step == "analyze"
          project.advance_onboarding!("sections")
        end
      else
        project.update!(analysis_status: "failed")
        Rails.logger.error "[AnalyzeCodebaseJob] Analysis failed for project #{project.id}: #{result[:error]}"
      end

      # Reload to ensure we have the latest data (including contextual_questions)
      project.reload

      # Broadcast update to the project page
      broadcast_analysis_update(project)

      # Broadcast to onboarding view if in wizard
      broadcast_onboarding_update(project) if project.in_onboarding? || project.onboarding_step == "sections"
    rescue StandardError => e
      project.update!(analysis_status: "failed")
      Rails.logger.error "[AnalyzeCodebaseJob] Analysis error for project #{project.id}: #{e.message}"
      raise e
    end
  end

  private

  def run_analysis(project, user)
    # Create a temporary directory for output
    output_dir = Rails.root.join("tmp", "analysis", "project_#{project.id}_#{Time.current.to_i}")
    FileUtils.mkdir_p(output_dir)
    # Make writable by container's non-root user
    FileUtils.chmod(0777, output_dir)

    begin
      # Build the Docker image if needed (or assume it's pre-built)
      docker_image = "rtfm/claude-analyzer:latest"

      # Check if we need to build the image
      build_docker_image_if_needed(docker_image)

      # Run the Docker container
      cmd = [
        "docker", "run",
        "--rm",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-e", "GITHUB_TOKEN=#{user.github_token}",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-v", "#{output_dir}:/output",
        "--network", "host",
        docker_image
      ]

      Rails.logger.info "[AnalyzeCodebaseJob] Running Docker analysis for #{project.github_repo}"
      Rails.logger.info "[AnalyzeCodebaseJob] Command: #{cmd.join(' ')}"

      stdout, stderr, status = Timeout.timeout(ANALYSIS_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[AnalyzeCodebaseJob] Exit status: #{status.exitstatus}"
      Rails.logger.info "[AnalyzeCodebaseJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.info "[AnalyzeCodebaseJob] Stderr: #{stderr[0..500]}" if stderr.present?

      # Check what files were created
      if Dir.exist?(output_dir)
        files = Dir.entries(output_dir) - [".", ".."]
        Rails.logger.info "[AnalyzeCodebaseJob] Output files: #{files.join(', ')}"
      end

      unless status.success?
        Rails.logger.error "[AnalyzeCodebaseJob] Docker command failed with exit status #{status.exitstatus}"
        Rails.logger.error "[AnalyzeCodebaseJob] STDOUT:\n#{stdout}" if stdout.present?
        Rails.logger.error "[AnalyzeCodebaseJob] STDERR:\n#{stderr}" if stderr.present?

        error_details = []
        error_details << "exit #{status.exitstatus}"
        error_details << "stdout: #{stdout[0..1000]}" if stdout.present?
        error_details << "stderr: #{stderr[0..1000]}" if stderr.present?
        return { success: false, error: "Docker command failed: #{error_details.join('; ')}" }
      end

      # Read the output files
      summary = File.read(File.join(output_dir, "summary.md")).strip rescue nil
      metadata_raw = File.read(File.join(output_dir, "metadata.json")).strip rescue nil
      commit_sha = File.read(File.join(output_dir, "commit_sha.txt")).strip rescue nil
      overview = File.read(File.join(output_dir, "overview.txt")).strip rescue nil
      target_users_raw = File.read(File.join(output_dir, "target_users.json")).strip rescue nil
      contextual_questions_raw = File.read(File.join(output_dir, "contextual_questions.json")).strip rescue nil

      # Parse metadata JSON (strip markdown code fences if present)
      metadata = begin
        if metadata_raw.present?
          # Remove ```json and ``` if Claude wrapped it in code fences
          clean_json = metadata_raw
            .gsub(/\A\s*```json\s*/i, "")
            .gsub(/\s*```\s*\z/, "")
            .strip
          JSON.parse(clean_json)
        end
      rescue JSON::ParserError => e
        Rails.logger.warn "[AnalyzeCodebaseJob] Failed to parse metadata JSON: #{e.message}"
        Rails.logger.warn "[AnalyzeCodebaseJob] Raw metadata: #{metadata_raw[0..200]}"
        nil
      end

      # Parse target users JSON and add to metadata
      if target_users_raw.present? && metadata
        begin
          clean_json = target_users_raw
            .gsub(/\A\s*```json\s*/i, "")
            .gsub(/\s*```\s*\z/, "")
            .strip
          metadata["target_users"] = JSON.parse(clean_json)
        rescue JSON::ParserError => e
          Rails.logger.warn "[AnalyzeCodebaseJob] Failed to parse target_users JSON: #{e.message}"
        end
      end

      # Parse contextual questions JSON
      contextual_questions = nil
      if contextual_questions_raw.present?
        begin
          clean_json = contextual_questions_raw
            .gsub(/\A\s*```json\s*/i, "")
            .gsub(/\s*```\s*\z/, "")
            .strip
          parsed = JSON.parse(clean_json)
          contextual_questions = parsed["questions"] || parsed
        rescue JSON::ParserError => e
          Rails.logger.warn "[AnalyzeCodebaseJob] Failed to parse contextual_questions JSON: #{e.message}"
        end
      end

      if summary.present?
        {
          success: true,
          summary: summary,
          metadata: metadata,
          commit_sha: commit_sha,
          overview: overview,
          contextual_questions: contextual_questions
        }
      else
        { success: false, error: "No summary generated" }
      end
    ensure
      # Cleanup temporary directory
      FileUtils.rm_rf(output_dir)
    end
  end

  def build_docker_image_if_needed(image_name)
    # Check if image exists
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      # Build the image
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[AnalyzeCodebaseJob] Building Docker image #{image_name}"

      _, stderr, status = Open3.capture3(
        "docker", "build", "-t", image_name, dockerfile_path.to_s
      )

      unless status.success?
        raise "Failed to build Docker image: #{stderr}"
      end
    end
  end

  def broadcast_analysis_update(project)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :analysis ],
      target: ActionView::RecordIdentifier.dom_id(project, :analysis),
      partial: "projects/analysis",
      locals: { project: project }
    )
  end

  def broadcast_onboarding_update(project)
    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :onboarding ],
      target: ActionView::RecordIdentifier.dom_id(project, :onboarding_analyze),
      partial: "onboarding/projects/analyze_status",
      locals: { project: project }
    )
  end

end

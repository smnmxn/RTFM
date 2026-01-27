require "open3"
require "fileutils"
require "json"
require "timeout"

class AnalyzeCodebaseJob < ApplicationJob
  include DockerVolumeHelper
  include ClaudeUsageTracker
  include ToastNotifier

  queue_as :analysis

  # Longer timeout for analysis (10 minutes)
  ANALYSIS_TIMEOUT = 600

  def perform(project_id)
    project = Project.find_by(id: project_id)
    return unless project
    # Check for either legacy installation or project_repositories
    return unless project.github_app_installation.present? || project.project_repositories.any?

    project.update!(analysis_status: "running")

    begin
      result = run_analysis(project)

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
        broadcast_toast(project, message: "Repository analysis complete", action_url: "/projects/#{project.slug}", action_label: "View")
        if result[:contextual_questions].present?
          Rails.logger.info "[AnalyzeCodebaseJob] Generated #{result[:contextual_questions].size} contextual questions"
        end

        # Trigger section suggestions after successful analysis
        project.update!(
          sections_generation_status: "pending",
          sections_generation_started_at: Time.current
        )
        SuggestSectionsJob.perform_later(project_id: project.id)

        # Auto-advance onboarding if in wizard
        if project.in_onboarding? && project.onboarding_step == "analyze"
          project.advance_onboarding!("sections")
        end

        # Broadcast update to show contextual questions
        broadcast_onboarding_update(project)
      else
        project.update!(analysis_status: "failed")
        Rails.logger.error "[AnalyzeCodebaseJob] Analysis failed for project #{project.id}: #{result[:error]}"
        broadcast_toast(project, message: "Repository analysis failed", type: "error", action_url: "/projects/#{project.slug}", action_label: "View")

        # Broadcast update to show error state
        broadcast_onboarding_update(project)
      end

      # Reload to ensure we have the latest data (including contextual_questions)
      project.reload
    rescue StandardError => e
      project.update!(analysis_status: "failed")
      Rails.logger.error "[AnalyzeCodebaseJob] Analysis error for project #{project.id}: #{e.message}"
      raise e
    end
  end

  private

  def run_analysis(project)
    # Create a temporary directory for output (uses shared host path in production)
    output_dir = create_analysis_output_dir("project_#{project.id}")

    begin
      # Build the Docker image if needed (or assume it's pre-built)
      docker_image = "rtfm/claude-analyzer:latest"

      # Check if we need to build the image
      build_docker_image_if_needed(docker_image)

      # Build repos JSON for multi-repo support
      repos_json = build_repos_json(project)
      Rails.logger.info "[AnalyzeCodebaseJob] Project #{project.id} has #{project.project_repositories.count} project_repositories"
      Rails.logger.info "[AnalyzeCodebaseJob] repos_json: #{repos_json.inspect}"

      if repos_json.empty?
        # Fall back to legacy single-repo mode
        Rails.logger.info "[AnalyzeCodebaseJob] Falling back to legacy mode. github_repo=#{project.github_repo.inspect}, installation_id=#{project.github_app_installation_id.inspect}"
        github_token = get_github_token(project)
        return { success: false, error: "No GitHub token available" } unless github_token

        cmd = [
          "docker", "run",
          "--rm",
          "-e", "GITHUB_REPO=#{project.primary_github_repo}",
          "-e", "GITHUB_TOKEN=#{github_token}",
          *claude_auth_docker_args,
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          docker_image
        ]
        Rails.logger.info "[AnalyzeCodebaseJob] Running Docker analysis (legacy mode) for #{project.primary_github_repo}"
      else
        # Multi-repo mode
        cmd = [
          "docker", "run",
          "--rm",
          "-e", "GITHUB_REPOS_JSON=#{repos_json.to_json}",
          *claude_auth_docker_args,
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          docker_image
        ]
        Rails.logger.info "[AnalyzeCodebaseJob] Running Docker analysis (multi-repo mode) for #{repos_json.size} repositories"
      end
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

      # Record usage for main analysis
      record_claude_usage(
        output_dir: output_dir,
        job_type: "analyze_codebase",
        project: project,
        metadata: { phase: "main_analysis" },
        success: status.success?,
        error_message: status.success? ? nil : stderr,
        usage_filename: "usage_main.json"
      )

      # Record usage for style analysis
      record_claude_usage(
        output_dir: output_dir,
        job_type: "analyze_codebase",
        project: project,
        metadata: { phase: "style_analysis" },
        success: status.success?,
        error_message: status.success? ? nil : stderr,
        usage_filename: "usage_style.json"
      )

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

      # Parse style context JSON and add to metadata
      style_context_path = File.join(output_dir, "style_context.json")
      Rails.logger.info "[AnalyzeCodebaseJob] Looking for style_context at: #{style_context_path}"
      Rails.logger.info "[AnalyzeCodebaseJob] File exists: #{File.exist?(style_context_path)}"

      style_context_raw = File.read(style_context_path).strip rescue nil
      Rails.logger.info "[AnalyzeCodebaseJob] style_context_raw present: #{style_context_raw.present?}, metadata present: #{metadata.present?}"

      if style_context_raw.present? && metadata
        begin
          # Extract JSON from markdown code fences if present, or find raw JSON object
          clean_json = if style_context_raw =~ /```json\s*(.*?)\s*```/m
            $1.strip
          elsif style_context_raw =~ /(\{[\s\S]*\})/
            $1.strip
          else
            style_context_raw
              .gsub(/\A\s*```json\s*/i, "")
              .gsub(/\s*```\s*\z/, "")
              .strip
          end
          metadata["style_context"] = JSON.parse(clean_json)
          Rails.logger.info "[AnalyzeCodebaseJob] Extracted style context: app_type=#{metadata['style_context']['app_type']}, framework=#{metadata['style_context']['framework']}"
        rescue JSON::ParserError => e
          Rails.logger.warn "[AnalyzeCodebaseJob] Failed to parse style_context JSON: #{e.message}"
          Rails.logger.warn "[AnalyzeCodebaseJob] Raw style_context: #{style_context_raw[0..200]}"
        end
      else
        Rails.logger.warn "[AnalyzeCodebaseJob] Skipping style_context: raw=#{style_context_raw.present?}, metadata=#{metadata.present?}"
      end

      # Parse repository relationships JSON (for multi-repo projects)
      repo_relationships_path = File.join(output_dir, "repository_relationships.json")
      repo_relationships_raw = File.read(repo_relationships_path).strip rescue nil

      if repo_relationships_raw.present? && metadata
        begin
          clean_json = if repo_relationships_raw =~ /```json\s*(.*?)\s*```/m
            $1.strip
          elsif repo_relationships_raw =~ /(\{[\s\S]*\})/
            $1.strip
          else
            repo_relationships_raw
              .gsub(/\A\s*```json\s*/i, "")
              .gsub(/\s*```\s*\z/, "")
              .strip
          end
          metadata["repository_relationships"] = JSON.parse(clean_json)
          Rails.logger.info "[AnalyzeCodebaseJob] Extracted repository relationships for #{metadata['repository_relationships']['repositories']&.size || 0} repos"
        rescue JSON::ParserError => e
          Rails.logger.warn "[AnalyzeCodebaseJob] Failed to parse repository_relationships JSON: #{e.message}"
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
      cleanup_analysis_dir(output_dir)
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
        Rails.logger.error "[AnalyzeCodebaseJob] Failed to get token for repo #{pr.github_repo}: #{e.message}"
        nil
      end
    end
  end

  def get_github_token(project)
    installation = project.github_app_installation

    unless installation
      Rails.logger.error "[AnalyzeCodebaseJob] Project #{project.id} has no GitHub App installation"
      return nil
    end

    # Verify the installation account matches the repo owner
    repo_owner = project.github_repo.split("/").first
    if installation.account_login != repo_owner
      Rails.logger.error "[AnalyzeCodebaseJob] Installation account '#{installation.account_login}' doesn't match repo owner '#{repo_owner}'"
      return nil
    end

    token = GithubAppService.installation_token(installation.github_installation_id)
    Rails.logger.info "[AnalyzeCodebaseJob] Got GitHub App token for installation #{installation.github_installation_id} (#{installation.account_login})"
    token
  rescue => e
    Rails.logger.error "[AnalyzeCodebaseJob] Failed to get GitHub App token: #{e.message}"
    nil
  end

  def broadcast_onboarding_update(project)
    # Broadcast to the onboarding channel to refresh the analyze status
    Rails.logger.info "[AnalyzeCodebaseJob] Broadcasting targeted update to onboarding_analyze"
    Turbo::StreamsChannel.broadcast_update_to(
      [project, :onboarding],
      target: ActionView::RecordIdentifier.dom_id(project, :onboarding_analyze),
      partial: "onboarding/projects/analyze_status",
      locals: { project: project }
    )
  end
end

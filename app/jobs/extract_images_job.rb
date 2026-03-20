require "open3"
require "fileutils"
require "timeout"

class ExtractImagesJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  EXTRACTION_TIMEOUT = 120 # 2 minutes (no Claude calls, just filesystem walk)

  def perform(project_id:)
    project = Project.find_by(id: project_id)
    return unless project
    return unless project.github_app_installation.present? || project.project_repositories.any?

    Rails.logger.info "[ExtractImagesJob] Starting image extraction for project #{project.id}"

    output_dir = create_analysis_output_dir("images_#{project.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"
      build_docker_image_if_needed(docker_image)

      # Build repos JSON for multi-repo support
      repos_json = build_repos_json(project)

      if repos_json.empty?
        # Fall back to legacy single-repo mode
        github_token = get_github_token(project)
        return unless github_token

        cmd = [
          "docker", "run",
          "--rm",
          "-e", "GITHUB_REPO=#{project.primary_github_repo}",
          "-e", "GITHUB_TOKEN=#{github_token}",
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          "--entrypoint", "/extract_images.sh",
          docker_image
        ]
      else
        # Multi-repo: use primary repo for extract_images
        primary = repos_json.first
        cmd = [
          "docker", "run",
          "--rm",
          "-e", "GITHUB_REPO=#{primary[:repo]}",
          "-e", "GITHUB_TOKEN=#{primary[:token]}",
          "-v", "#{host_volume_path(output_dir)}:/output",
          "--network", "host",
          "--entrypoint", "/extract_images.sh",
          docker_image
        ]
      end

      Rails.logger.info "[ExtractImagesJob] Running Docker image extraction for project #{project.id}"

      stdout, stderr, status = Timeout.timeout(EXTRACTION_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[ExtractImagesJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[ExtractImagesJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[ExtractImagesJob] Stderr: #{stderr[0..500]}" if stderr.present?

      if status.success?
        images_path = File.join(output_dir, "images_base64.json")
        images_content = File.read(images_path).strip rescue nil

        if images_content.present?
          parsed = JSON.parse(images_content)
          image_count = parsed["count"] || 0
          total_bytes = parsed["total_b64_bytes"] || 0

          # Store in analysis_metadata
          metadata = project.analysis_metadata || {}
          metadata["images_base64"] = parsed
          project.update!(analysis_metadata: metadata)
          Rails.logger.info "[ExtractImagesJob] Extracted #{image_count} images (#{total_bytes / 1024}KB base64) for project #{project.id}"
        else
          Rails.logger.warn "[ExtractImagesJob] No images extracted for project #{project.id}"
        end
      else
        Rails.logger.error "[ExtractImagesJob] Image extraction failed for project #{project.id}: #{stderr}"
      end
    rescue Timeout::Error
      Rails.logger.error "[ExtractImagesJob] Image extraction timed out for project #{project.id}"
    rescue StandardError => e
      Rails.logger.error "[ExtractImagesJob] Error extracting images for project #{project.id}: #{e.message}"
    ensure
      cleanup_analysis_dir(output_dir)
    end
  end

  private

  def build_repos_json(project)
    project.project_repositories.filter_map do |pr|
      begin
        adapter = pr.vcs_adapter
        token = adapter.installation_token(pr.github_installation_id)
        {
          repo: pr.github_repo,
          directory: pr.clone_directory_name,
          token: token,
          clone_url: adapter.clone_url(pr.github_repo, token)
        }
      rescue => e
        Rails.logger.error "[ExtractImagesJob] Failed to get token for repo #{pr.github_repo}: #{e.message}"
        nil
      end
    end
  end

  def build_docker_image_if_needed(image_name)
    stdout, _, status = Open3.capture3("docker", "images", "-q", image_name)

    if stdout.strip.empty?
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      Rails.logger.info "[ExtractImagesJob] Building Docker image #{image_name}"

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
    Rails.logger.error "[ExtractImagesJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

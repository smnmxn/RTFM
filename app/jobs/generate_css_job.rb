require "open3"
require "fileutils"
require "timeout"

class GenerateCssJob < ApplicationJob
  include DockerVolumeHelper

  queue_as :analysis

  GENERATION_TIMEOUT = 300 # 5 minutes

  def perform(project_id:)
    project = Project.find_by(id: project_id)
    return unless project
    return unless project.github_app_installation.present?

    Rails.logger.info "[GenerateCssJob] Starting CSS generation for project #{project.id}"

    output_dir = create_analysis_output_dir("css_#{project.id}")

    begin
      docker_image = "rtfm/claude-analyzer:latest"

      github_token = get_github_token(project)
      return unless github_token

      cmd = [
        "docker", "run",
        "--rm",
        "-e", "GITHUB_REPO=#{project.github_repo}",
        "-e", "GITHUB_TOKEN=#{github_token}",
        "-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}",
        "-v", "#{host_volume_path(output_dir)}:/output",
        "--network", "host",
        "--entrypoint", "/generate_css.sh",
        docker_image
      ]

      Rails.logger.info "[GenerateCssJob] Running Docker CSS generation for #{project.github_repo}"

      stdout, stderr, status = Timeout.timeout(GENERATION_TIMEOUT) do
        Open3.capture3(*cmd)
      end

      Rails.logger.info "[GenerateCssJob] Exit status: #{status.exitstatus}"
      Rails.logger.debug "[GenerateCssJob] Stdout: #{stdout[0..500]}" if stdout.present?
      Rails.logger.debug "[GenerateCssJob] Stderr: #{stderr[0..500]}" if stderr.present?

      if status.success?
        css_path = File.join(output_dir, "compiled_css.txt")
        css_content = File.read(css_path).strip rescue nil

        if css_content.present?
          # Store in analysis_metadata
          metadata = project.analysis_metadata || {}
          metadata["compiled_css"] = css_content
          project.update!(analysis_metadata: metadata)
          Rails.logger.info "[GenerateCssJob] Generated #{css_content.length} bytes of CSS for project #{project.id}"
        else
          Rails.logger.warn "[GenerateCssJob] No CSS content generated for project #{project.id}"
        end
      else
        Rails.logger.error "[GenerateCssJob] CSS generation failed for project #{project.id}: #{stderr}"
      end
    rescue Timeout::Error
      Rails.logger.error "[GenerateCssJob] CSS generation timed out for project #{project.id}"
    rescue StandardError => e
      Rails.logger.error "[GenerateCssJob] Error generating CSS for project #{project.id}: #{e.message}"
    ensure
      cleanup_analysis_dir(output_dir)
    end
  end

  private

  def get_github_token(project)
    installation = project.github_app_installation
    return nil unless installation

    GithubAppService.installation_token(installation.github_installation_id)
  rescue => e
    Rails.logger.error "[GenerateCssJob] Failed to get GitHub token: #{e.message}"
    nil
  end
end

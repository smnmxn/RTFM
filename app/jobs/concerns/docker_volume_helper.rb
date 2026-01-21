# frozen_string_literal: true

module DockerVolumeHelper
  extend ActiveSupport::Concern

  # Shared host path for analysis output in production (Kamal deployment)
  PRODUCTION_ANALYSIS_PATH = "/var/supportpages/analysis"

  private

  # Get the base directory for analysis output.
  # In production (Kamal), uses a shared host directory.
  # In development, uses Rails tmp directory.
  def analysis_output_base
    if Rails.env.production?
      PRODUCTION_ANALYSIS_PATH
    else
      Rails.root.join("tmp", "analysis").to_s
    end
  end

  # Create a unique directory for analysis (input or output)
  def create_analysis_dir(prefix, writable: false)
    dir = File.join(analysis_output_base, "#{prefix}_#{Time.current.to_i}_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(dir)
    FileUtils.chmod(0777, dir) if writable
    dir
  end

  # Create a unique output directory for analysis (world-writable for container)
  def create_analysis_output_dir(prefix)
    create_analysis_dir(prefix, writable: true)
  end

  # Create a unique input directory for analysis
  def create_analysis_input_dir(prefix)
    create_analysis_dir(prefix, writable: false)
  end

  # Conditionally clean up analysis directory based on environment variable.
  # Set KEEP_ANALYSIS_OUTPUT=true to preserve output files for debugging.
  def cleanup_analysis_dir(dir)
    return if dir.blank?

    if ENV["KEEP_ANALYSIS_OUTPUT"] == "true"
      Rails.logger.info "[DockerVolumeHelper] Keeping output directory: #{dir}"
    else
      FileUtils.rm_rf(dir)
    end
  end

  # Translate container path to host path for Docker volume mounts.
  # When running in Docker, Rails.root is /rails but the host path differs.
  # Sibling containers need the host path for volume mounts.
  def host_volume_path(container_path)
    container_path = container_path.to_s

    # Production analysis paths are already host paths (direct bind mount)
    return container_path if container_path.start_with?(PRODUCTION_ANALYSIS_PATH)

    if ENV["HOST_PROJECT_PATH"].present?
      rails_root_in_container = Rails.root.to_s
      container_path.sub(rails_root_in_container, ENV["HOST_PROJECT_PATH"])
    else
      container_path
    end
  end

  # Returns Docker arguments for Claude authentication.
  # Supports (in priority order):
  # - CLAUDE_CODE_OAUTH_TOKEN: Token from `claude setup-token` (Max subscription)
  # - ANTHROPIC_API_KEY: Standard API key
  def claude_auth_docker_args
    if ENV["CLAUDE_CODE_OAUTH_TOKEN"].present?
      ["-e", "CLAUDE_CODE_OAUTH_TOKEN=#{ENV['CLAUDE_CODE_OAUTH_TOKEN']}"]
    else
      ["-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}"]
    end
  end
end

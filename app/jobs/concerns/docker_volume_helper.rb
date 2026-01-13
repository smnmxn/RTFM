# frozen_string_literal: true

module DockerVolumeHelper
  extend ActiveSupport::Concern

  private

  # Translate container path to host path for Docker volume mounts.
  # When running in Docker, Rails.root is /rails but the host path differs.
  # Sibling containers need the host path for volume mounts.
  def host_volume_path(container_path)
    container_path = container_path.to_s

    if ENV["HOST_PROJECT_PATH"].present?
      rails_root_in_container = Rails.root.to_s
      container_path.sub(rails_root_in_container, ENV["HOST_PROJECT_PATH"])
    else
      container_path
    end
  end
end

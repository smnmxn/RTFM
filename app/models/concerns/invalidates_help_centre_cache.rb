# frozen_string_literal: true

# Concern for models that should invalidate the Help Centre AI answer cache
# when their content changes. Include this in Article and Section models.
#
# When included, call `invalidate_help_centre_cache!` after making changes
# that should bust the cache. The model must implement `project_for_cache`
# to return the associated project.
module InvalidatesHelpCentreCache
  extend ActiveSupport::Concern

  included do
    after_commit :maybe_invalidate_help_centre_cache
  end

  private

  def maybe_invalidate_help_centre_cache
    return unless should_invalidate_help_centre_cache?

    invalidate_help_centre_cache!
  end

  def invalidate_help_centre_cache!
    project = project_for_cache
    return unless project

    new_version = project.help_centre_cache_version + 1
    project.update_column(:help_centre_cache_version, new_version)
    Rails.logger.info "[HelpCentreCache] INVALIDATE project=#{project.id} new_version=#{new_version}"
  end

  # Override in including class to return the project
  def project_for_cache
    respond_to?(:project) ? project : nil
  end

  # Override in including class to determine when to invalidate
  def should_invalidate_help_centre_cache?
    false
  end
end

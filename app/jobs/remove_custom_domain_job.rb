class RemoveCustomDomainJob < ApplicationJob
  queue_as :default

  def perform(cloudflare_id:)
    return if cloudflare_id.blank?

    Rails.logger.info "[RemoveCustomDomainJob] Removing custom hostname: #{cloudflare_id}"

    service = CloudflareCustomHostnameService.new
    return unless service.configured?

    service.delete_custom_hostname(cloudflare_id)
    Rails.logger.info "[RemoveCustomDomainJob] Successfully removed custom hostname: #{cloudflare_id}"

  rescue CloudflareCustomHostnameService::ApiError => e
    # Log but don't fail - the hostname might already be deleted
    Rails.logger.warn "[RemoveCustomDomainJob] Cloudflare API error (may be already deleted): #{e.message}"
  end
end

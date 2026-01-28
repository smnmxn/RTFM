class CheckCustomDomainStatusJob < ApplicationJob
  queue_as :default

  MAX_RETRIES = 120 # Check for up to 1 hour (30 second intervals)
  RETRY_INTERVAL = 30.seconds

  def perform(project_id:, retry_count: 0)
    project = Project.find(project_id)

    return unless project.custom_domain.present?
    return unless project.custom_domain_cloudflare_id.present?
    return unless project.custom_domain_status == "verifying"

    Rails.logger.info "[CheckCustomDomainStatusJob] Checking status for #{project.custom_domain} (attempt #{retry_count + 1})"

    service = CloudflareCustomHostnameService.new
    result = service.get_custom_hostname(project.custom_domain_cloudflare_id)

    Rails.logger.info "[CheckCustomDomainStatusJob] Status: #{result[:status]}, SSL: #{result[:ssl_status]}"

    case result[:status]
    when "active"
      project.update!(
        custom_domain_status: "active",
        custom_domain_ssl_status: result[:ssl_status],
        custom_domain_verified_at: Time.current
      )
      Rails.logger.info "[CheckCustomDomainStatusJob] Domain #{project.custom_domain} is now active"

    when "pending", "pending_validation", "pending_issuance", "pending_deployment"
      project.update!(custom_domain_ssl_status: result[:ssl_status])

      if retry_count < MAX_RETRIES
        CheckCustomDomainStatusJob.set(wait: RETRY_INTERVAL).perform_later(
          project_id: project.id,
          retry_count: retry_count + 1
        )
      else
        Rails.logger.warn "[CheckCustomDomainStatusJob] Max retries reached for #{project.custom_domain}"
        # Keep status as verifying - user can manually refresh
      end

    when "blocked", "moved", "deleted"
      project.update!(
        custom_domain_status: "failed",
        custom_domain_ssl_status: result[:status]
      )
      Rails.logger.error "[CheckCustomDomainStatusJob] Domain #{project.custom_domain} failed: #{result[:status]}"
    end

  rescue CloudflareCustomHostnameService::ApiError => e
    Rails.logger.error "[CheckCustomDomainStatusJob] Cloudflare API error: #{e.message}"
    # Retry on transient errors
    if retry_count < MAX_RETRIES
      CheckCustomDomainStatusJob.set(wait: RETRY_INTERVAL).perform_later(
        project_id: project.id,
        retry_count: retry_count + 1
      )
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.info "[CheckCustomDomainStatusJob] Project #{project_id} not found, skipping"
  end
end

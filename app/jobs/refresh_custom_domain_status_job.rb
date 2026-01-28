class RefreshCustomDomainStatusJob < ApplicationJob
  queue_as :low

  def perform
    Rails.logger.info "[RefreshCustomDomainStatusJob] Starting periodic custom domain health check"

    service = CloudflareCustomHostnameService.new
    return unless service.configured?

    # Check all active custom domains
    Project.where(custom_domain_status: "active").where.not(custom_domain_cloudflare_id: nil).find_each do |project|
      check_domain(service, project)
    end

    # Also re-check verifying domains that might have stalled
    Project.where(custom_domain_status: "verifying").where.not(custom_domain_cloudflare_id: nil).find_each do |project|
      check_domain(service, project)
    end

    Rails.logger.info "[RefreshCustomDomainStatusJob] Completed periodic custom domain health check"
  end

  private

  def check_domain(service, project)
    result = service.get_custom_hostname(project.custom_domain_cloudflare_id)

    case result[:status]
    when "active"
      project.update!(
        custom_domain_status: "active",
        custom_domain_ssl_status: result[:ssl_status],
        custom_domain_verified_at: Time.current
      )
    when "pending", "pending_validation", "pending_issuance", "pending_deployment"
      project.update!(
        custom_domain_status: "verifying",
        custom_domain_ssl_status: result[:ssl_status]
      )
    when "blocked", "moved", "deleted"
      project.update!(
        custom_domain_status: "failed",
        custom_domain_ssl_status: result[:status]
      )
      Rails.logger.warn "[RefreshCustomDomainStatusJob] Domain #{project.custom_domain} is #{result[:status]}"
    end

  rescue CloudflareCustomHostnameService::ApiError => e
    Rails.logger.error "[RefreshCustomDomainStatusJob] Error checking #{project.custom_domain}: #{e.message}"
  rescue => e
    Rails.logger.error "[RefreshCustomDomainStatusJob] Unexpected error for #{project.custom_domain}: #{e.message}"
  end
end

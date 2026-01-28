class SetupCustomDomainJob < ApplicationJob
  queue_as :default

  def perform(project_id:)
    project = Project.find(project_id)
    return unless project.custom_domain.present?
    return unless project.custom_domain_status == "pending"

    Rails.logger.info "[SetupCustomDomainJob] Setting up custom domain #{project.custom_domain} for project #{project.id}"

    service = CloudflareCustomHostnameService.new

    unless service.configured?
      Rails.logger.error "[SetupCustomDomainJob] Cloudflare not configured, marking as failed"
      project.update!(
        custom_domain_status: "failed",
        custom_domain_ssl_status: "configuration_error"
      )
      return
    end

    result = service.create_custom_hostname(project.custom_domain)

    project.update!(
      custom_domain_cloudflare_id: result[:id],
      custom_domain_status: "verifying",
      custom_domain_ssl_status: result[:ssl_status]
    )

    Rails.logger.info "[SetupCustomDomainJob] Custom hostname created: #{result[:id]}, status: #{result[:status]}"

    # Schedule a check in 30 seconds
    CheckCustomDomainStatusJob.set(wait: 30.seconds).perform_later(project_id: project.id)
  rescue CloudflareCustomHostnameService::ApiError => e
    Rails.logger.error "[SetupCustomDomainJob] Cloudflare API error: #{e.message}"
    project.update!(
      custom_domain_status: "failed",
      custom_domain_ssl_status: "api_error"
    )
  rescue => e
    Rails.logger.error "[SetupCustomDomainJob] Unexpected error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    project.update!(custom_domain_status: "failed")
  end
end

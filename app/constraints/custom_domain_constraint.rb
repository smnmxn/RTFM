class CustomDomainConstraint
  def self.matches?(request)
    host = request.host.downcase
    base_domain = Rails.application.config.x.base_domain&.split(":")&.first

    return false if base_domain.blank?
    return false if host == base_domain
    return false if host.end_with?(".#{base_domain}")

    Project.exists?(custom_domain: host, custom_domain_status: "active")
  end

  def self.find_project(request)
    host = request.host.downcase
    Project.find_by(custom_domain: host, custom_domain_status: "active")
  end
end

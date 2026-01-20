class SubdomainConstraint
  EXCLUDED_SUBDOMAINS = %w[www api admin app].freeze

  def self.matches?(request)
    subdomain = extract_subdomain(request)
    subdomain.present? && !excluded_subdomain?(subdomain)
  end

  def self.extract_subdomain(request)
    host = request.host
    base_domain = Rails.application.config.x.base_domain

    return nil if base_domain.blank?

    # Remove port from base_domain if present for comparison
    base_domain_without_port = base_domain.split(":").first

    # Handle the case where host matches base domain exactly (no subdomain)
    return nil if host == base_domain_without_port

    # Extract subdomain
    if host.end_with?(".#{base_domain_without_port}")
      host.sub(/\.#{Regexp.escape(base_domain_without_port)}\z/, "")
    else
      nil
    end
  end

  def self.excluded_subdomain?(subdomain)
    EXCLUDED_SUBDOMAINS.include?(subdomain.downcase)
  end
end

class AppSubdomainConstraint
  def self.matches?(request)
    # In E2E tests, accept any host since subdomain routing is hard to set up
    # The E2E test environment sets SKIP_SUBDOMAIN_CONSTRAINT=true
    return true if ENV["SKIP_SUBDOMAIN_CONSTRAINT"] == "true"

    subdomain = SubdomainConstraint.extract_subdomain(request)
    subdomain&.downcase == "app"
  end
end

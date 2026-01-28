class AppSubdomainConstraint
  def self.matches?(request)
    subdomain = SubdomainConstraint.extract_subdomain(request)
    subdomain&.downcase == "app"
  end
end

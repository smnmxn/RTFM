# Run with: COVERAGE=1 rails test
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch

    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Services", "app/services"
    add_group "Jobs", "app/jobs"
    add_group "Helpers", "app/helpers"
    add_group "Mailers", "app/mailers"
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

OmniAuth.config.test_mode = true

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disable parallelization when measuring coverage (COVERAGE=1 rails test)
    parallelize(workers: ENV["COVERAGE"] ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
    # Set the request host to the app subdomain so routes behind
    # AppSubdomainConstraint are reachable in integration tests.
    def use_app_subdomain
      base = Rails.application.config.x.base_domain.split(":").first
      port = Rails.application.config.x.base_domain.split(":")[1]
      app_host = "app.#{base}"
      app_host = "#{app_host}:#{port}" if port.present?
      host! app_host
    end

    def sign_in_as(user)
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
        provider: "github",
        uid: user.github_uid,
        info: {
          email: user.email,
          name: user.name,
          nickname: user.github_username
        },
        credentials: {
          token: user.github_token
        }
      })

      use_app_subdomain
      post "/auth/github"
      follow_redirect!
      use_app_subdomain # Restore host in case OmniAuth redirect changed it
    end

    def sign_out
      delete logout_path
    end
  end
end

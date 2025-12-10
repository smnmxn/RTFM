ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

OmniAuth.config.test_mode = true

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module ActionDispatch
  class IntegrationTest
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

      post "/auth/github"
      follow_redirect!
    end

    def sign_out
      delete logout_path
    end
  end
end

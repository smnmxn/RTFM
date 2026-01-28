module E2E
  module AuthHelpers
    # Log in as a user by mocking the OAuth callback
    # This uses OmniAuth test mode which is already configured in test_helper.rb
    def login_as(user)
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
        provider: "github",
        uid: user.github_uid,
        info: {
          email: user.email,
          name: user.name,
          nickname: user.github_username
        },
        credentials: {
          token: user.github_token || "fake_token_for_testing"
        }
      })

      # Trigger OAuth callback directly
      visit "/auth/github/callback"
      wait_for_turbo
    end

    # Configure mock auth for a new user (not in database)
    def configure_new_user_auth(uid: "new_user_#{SecureRandom.hex(4)}", email: "newuser@example.com", name: "New User", nickname: "newuser")
      OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
        provider: "github",
        uid: uid,
        info: {
          email: email,
          name: name,
          nickname: nickname
        },
        credentials: {
          token: "fake_token_for_testing"
        }
      })
    end

    def logout
      visit "/logout"
      wait_for_turbo
    end

    def signed_in?
      !@page.locator("a:has-text('Sign in')").visible? rescue false
    end
  end
end

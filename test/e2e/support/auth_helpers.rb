module E2E
  module AuthHelpers
    # Log in as a user by posting to the test-only login endpoint.
    # This bypasses OAuth because OmniAuth mocks don't work across threads
    # (the test process and the Puma server run in separate threads).
    def login_as(user)
      # Navigate to health check first to establish browser context
      @page.goto("#{base_url}/up")

      # Inject a form and submit it to POST to the test login endpoint
      # The form will redirect to /projects after successful login
      redirect_url = "#{base_url}/projects"
      @page.evaluate(<<~JS)
        () => {
          const form = document.createElement('form');
          form.method = 'POST';
          form.action = '/test/login/#{user.id}';

          const redirectInput = document.createElement('input');
          redirectInput.type = 'hidden';
          redirectInput.name = 'redirect_to';
          redirectInput.value = '#{redirect_url}';
          form.appendChild(redirectInput);

          document.body.appendChild(form);
          form.submit();
        }
      JS

      # Wait for navigation to complete (will land on /projects)
      @page.wait_for_load_state(state: "networkidle")
      wait_for_turbo
    end

    # Alternative: Log in via OAuth flow (may not work reliably due to thread issues)
    # Kept for reference but login_as above is preferred.
    def login_via_oauth(user)
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

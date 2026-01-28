require_relative "base_page"

module E2E
  module Pages
    class LoginPage < BasePage
      PATH = "/login".freeze

      def visit
        page.goto("#{test_case.send(:base_url)}#{PATH}")
        wait_for_turbo
        self
      end

      def visit_with_invite(token)
        page.goto("#{test_case.send(:base_url)}/invite/#{token}")
        wait_for_turbo
        self
      end

      def sign_in_with_github
        click("button:has-text('Sign in with GitHub')")
        wait_for_turbo
      end

      def join_waitlist(email)
        fill("input[type='email']", email)
        click("input[value='Join']")
        wait_for_turbo
        # Wait for page to fully load after redirect
        page.wait_for_load_state(state: "networkidle")
      end

      # Page element checks
      def has_github_button?
        has_element?("button:has-text('Sign in with GitHub')")
      end

      def has_create_account_button?
        has_element?("button:has-text('Create account')")
      end

      def has_waitlist_form?
        has_element?("input[type='email']")
      end

      def has_logo?
        has_element?("img[alt='supportpages.io']")
      end

      def has_tagline?
        has_text?("Support pages that write and maintain themselves")
      end

      def has_video_placeholder?
        # Check for the play button SVG within the video placeholder
        has_element?(".bg-slate-100") && has_element?("svg path[d='M8 5v14l11-7z']")
      end

      def has_existing_users_section?
        has_text?("Existing users")
      end

      def has_waitlist_section?
        has_text?("New here?")
      end

      # Flash message checks
      def has_notice_message?(text)
        has_element?(".bg-emerald-50") && has_text?(text)
      end

      def has_alert_message?(text)
        has_element?(".bg-red-50") && has_text?(text)
      end

      def has_error_message?
        has_text?("error") || has_text?("failed") || has_text?("invalid")
      end

      # Invite flow specific checks
      def has_invite_ready_message?
        has_text?("Your invite is ready")
      end
    end
  end
end

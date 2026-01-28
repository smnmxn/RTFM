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

      def sign_in_with_github
        click("button:has-text('Sign in with GitHub')")
        wait_for_turbo
      end

      def join_waitlist(email)
        fill("input[type='email']", email)
        click("input[type='submit']")
        wait_for_turbo
      end

      def has_github_button?
        has_element?("button:has-text('Sign in with GitHub')")
      end

      def has_waitlist_form?
        has_element?("input[type='email']")
      end

      def has_error_message?
        has_text?("error") || has_text?("failed") || has_text?("invalid")
      end
    end
  end
end

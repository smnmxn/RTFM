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

      def open_login_modal
        click("#hero-cta button[data-login-toggle-mode-param='signin']")
        page.wait_for_selector("[data-login-toggle-target='modal']:not(.hidden)", timeout: 5000)
      end

      def open_signup_modal
        click("#hero-cta button[data-login-toggle-mode-param='register']")
        page.wait_for_selector("[data-login-toggle-target='modal']:not(.hidden)", timeout: 5000)
      end

      # Page element checks (hero page)
      def has_login_button?
        has_element?("#hero-cta button[data-login-toggle-mode-param='signin']")
      end

      def has_signup_button?
        has_element?("#hero-cta button[data-login-toggle-mode-param='register']")
      end

      def has_logo?
        has_element?("img[alt='supportpages.io']") || has_element?("a[href='/'] img")
      end

      def has_tagline?
        has_text?("Your docs are out of date")
      end

      def has_video_placeholder?
        has_element?("[data-controller*='video-player']") && has_element?("svg path[d='M8 5v14l11-7z']")
      end

      # Modal element checks (must open modal first)
      def has_github_button?
        has_element?("button:has-text('Continue with GitHub')")
      end

      def has_google_button?
        has_element?("button:has-text('Continue with Google')")
      end

      def has_apple_button?
        has_element?("button:has-text('Continue with Apple')")
      end

      def has_modal_open?
        has_element?("[data-login-toggle-target='modal']:not(.hidden)")
      end

      # Flash message checks
      def has_notice_message?(text)
        has_element?("[class*='bg-emerald']") && has_text?(text)
      end

      def has_alert_message?(text)
        has_element?("[class*='bg-red']") && has_text?(text)
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

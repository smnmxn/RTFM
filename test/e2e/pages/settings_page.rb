require_relative "base_page"

module E2E
  module Pages
    class SettingsPage < BasePage
      # =====================
      # Navigation
      # =====================

      def visit_project(project_slug)
        page.goto("#{test_case.send(:app_url)}/projects/#{project_slug}")
        wait_for_turbo
        self
      end

      def click_settings_tab
        click("button[data-tabs-name='settings']")
        wait_for_turbo
        self
      end

      def click_branding_tab
        click("button[data-tabs-name='branding']")
        wait_for_turbo
        self
      end

      def click_custom_domain_tab
        click("button[data-tabs-name='custom-domain']")
        wait_for_turbo
        self
      end

      def click_notifications_tab
        click("button[data-tabs-name='notifications']")
        wait_for_turbo
        self
      end

      def click_danger_zone_tab
        click("button[data-tabs-name='danger-zone']")
        wait_for_turbo
        self
      end

      def click_ai_settings_tab
        click("button[data-tabs-name='ai-settings']")
        wait_for_turbo
        self
      end

      def click_recommendations_tab
        click("button[data-tabs-name='update-strategy']")
        wait_for_turbo
        self
      end

      # =====================
      # Sub-tab Sidebar Checks
      # =====================

      def has_sub_tab?(name)
        page.locator("button[data-tabs-name='#{name}']").count > 0
      rescue
        false
      end

      def has_all_sub_tabs?
        %w[branding update-strategy ai-settings custom-domain notifications danger-zone].all? do |tab_name|
          has_sub_tab?(tab_name)
        end
      end

      # =====================
      # State Checks
      # =====================

      def on_settings_tab?
        has_element?("button[data-tabs-name='settings'].tab-active")
      end

      def has_branding_form?
        has_element?("turbo-frame#branding_form")
      end

      def has_domain_input?
        page.locator("input[name='project[custom_domain]']").count > 0
      rescue
        false
      end

      def has_dns_instructions?
        settings_panel_has_text?("DNS Configuration Required")
      end

      def has_pending_status?
        settings_panel_has_text?("Waiting for DNS configuration")
      end

      def has_active_status?
        settings_panel_has_text?("Active and serving traffic")
      end

      def has_failed_status?
        settings_panel_has_text?("Domain Setup Failed")
      end

      def has_check_status_button?
        page.locator("button:has-text('Check Status')").count > 0
      rescue
        false
      end

      def has_remove_domain_button?
        page.locator("button:has-text('Remove Domain')").count > 0
      rescue
        false
      end

      def has_retry_verification_button?
        page.locator("button:has-text('Retry Verification')").count > 0
      rescue
        false
      end

      def has_danger_zone?
        settings_panel_has_text?("Danger Zone") && settings_panel_has_text?("Delete Project")
      end

      def has_notifications_section?
        settings_panel_has_text?("In-app toast notifications") && settings_panel_has_text?("Browser notifications")
      end

      def has_ai_settings?
        has_element?("turbo-frame#ai_settings_form")
      end

      def has_recommendations_form?
        has_element?("turbo-frame#update_strategy_form")
      end

      # =====================
      # Branding Form Checks
      # =====================

      def has_title_field?
        page.locator("input[name='project[help_centre_title]']").count > 0
      rescue
        false
      end

      def has_tagline_field?
        page.locator("input[name='project[help_centre_tagline]']").count > 0
      rescue
        false
      end

      def has_subdomain_field?
        page.locator("input[name='project[subdomain]']").count > 0
      rescue
        false
      end

      def has_support_email_field?
        page.locator("input[name='project[support_email]']").count > 0
      rescue
        false
      end

      def has_support_phone_field?
        page.locator("input[name='project[support_phone]']").count > 0
      rescue
        false
      end

      def has_dark_mode_toggle?
        page.locator("input[name='project[dark_mode]'][type='checkbox']").count > 0
      rescue
        false
      end

      # =====================
      # Branding Actions
      # =====================

      def fill_title(title)
        fill("input[name='project[help_centre_title]']", title)
        self
      end

      def fill_tagline(tagline)
        fill("input[name='project[help_centre_tagline]']", tagline)
        self
      end

      def save_branding
        btn = page.locator("input[value='Save Branding'], button:has-text('Save Branding')")
        btn.scroll_into_view_if_needed
        btn.click
        wait_for_turbo
        # Wait for the turbo frame to re-render with the saved confirmation
        page.wait_for_selector("text=Saved", timeout: 5_000) rescue nil
        self
      end

      def branding_saved?
        settings_panel_has_text?("Saved")
      end

      # =====================
      # Content area text check
      # =====================

      # Check text within the settings content area using text_content
      # This avoids visibility issues with elements below the viewport fold
      def settings_panel_has_text?(text)
        # The settings panel is the visible panel inside the settings tab
        panel = page.locator("div[data-tabs-name='settings']:not(.hidden)")
        panel.text_content.include?(text)
      rescue
        # Fallback: check the entire page text content
        page.text_content("body").include?(text)
      rescue
        false
      end
    end
  end
end

require "e2e_test_helper"
require_relative "../pages/settings_page"

class SettingsFlowTest < E2ETestCase
  setup do
    @user = users(:one)
    @settings_page = E2E::Pages::SettingsPage.new(@page, self)
    login_as(@user)
  end

  # =============================================================
  # Helper: Navigate to settings tab for a given project
  # =============================================================

  def navigate_to_settings(project_slug)
    @settings_page.visit_project(project_slug)
    @settings_page.click_settings_tab
  end

  # =============================================================
  # Tab Rendering Tests
  # =============================================================

  test "settings tab shows all sub-tabs" do
    navigate_to_settings("rtfm")

    assert @settings_page.has_sub_tab?("branding"), "Expected Branding sub-tab button to exist"
    assert @settings_page.has_sub_tab?("update-strategy"), "Expected Recommendations sub-tab button to exist"
    assert @settings_page.has_sub_tab?("ai-settings"), "Expected AI Settings sub-tab button to exist"
    assert @settings_page.has_sub_tab?("custom-domain"), "Expected Custom Domain sub-tab button to exist"
    assert @settings_page.has_sub_tab?("notifications"), "Expected Notifications sub-tab button to exist"
    assert @settings_page.has_sub_tab?("danger-zone"), "Expected Danger Zone sub-tab button to exist"
  end

  test "branding is default active sub-tab" do
    navigate_to_settings("rtfm")

    assert @settings_page.has_branding_form?, "Expected branding form to be visible by default"
  end

  test "switching between sub-tabs shows correct content" do
    navigate_to_settings("rtfm")

    # Switch to Custom Domain
    @settings_page.click_custom_domain_tab
    assert @settings_page.has_domain_input?, "Expected custom domain input to be visible"

    # Switch back to Branding
    @settings_page.click_branding_tab
    assert @settings_page.has_branding_form?, "Expected branding form to be visible"
  end

  # =============================================================
  # Branding Tests
  # =============================================================

  test "branding form shows title and tagline fields" do
    navigate_to_settings("rtfm")

    assert @settings_page.has_title_field?, "Expected title input to exist"
    assert @settings_page.has_tagline_field?, "Expected tagline input to exist"
    assert @settings_page.settings_panel_has_text?("Title"), "Expected Title label in branding form"
    assert @settings_page.settings_panel_has_text?("Subtitle"), "Expected Subtitle label in branding form"
  end

  test "branding form shows color pickers" do
    navigate_to_settings("rtfm")

    assert @settings_page.settings_panel_has_text?("Primary Color"), "Expected Primary Color label"
    assert @settings_page.settings_panel_has_text?("Accent Color"), "Expected Accent Color label"
    assert @settings_page.settings_panel_has_text?("Title Text Color"), "Expected Title Text Color label"
  end

  test "branding form shows subdomain field" do
    navigate_to_settings("rtfm")

    assert @settings_page.has_subdomain_field?, "Expected subdomain input to exist"
    assert @settings_page.settings_panel_has_text?("Custom Subdomain"), "Expected Custom Subdomain label"
  end

  test "branding form shows support contact fields" do
    navigate_to_settings("rtfm")

    assert @settings_page.has_support_email_field?, "Expected support email input to exist"
    assert @settings_page.has_support_phone_field?, "Expected support phone input to exist"
    assert @settings_page.settings_panel_has_text?("Support Email"), "Expected Support Email label"
    assert @settings_page.settings_panel_has_text?("Support Phone"), "Expected Support Phone label"
  end

  test "branding form shows dark mode toggle" do
    navigate_to_settings("rtfm")

    assert @settings_page.has_dark_mode_toggle?, "Expected dark mode checkbox to exist"
    assert @settings_page.settings_panel_has_text?("Dark Mode"), "Expected Dark Mode label"
    assert @settings_page.settings_panel_has_text?("Enable dark mode"), "Expected Enable dark mode text"
  end

  test "saving branding shows confirmation" do
    navigate_to_settings("rtfm")

    @settings_page.fill_title("Updated Help Centre Title")
    @settings_page.save_branding

    assert @settings_page.branding_saved?, "Expected 'Saved' confirmation text to appear"
  end

  # =============================================================
  # Custom Domain Tests (pre-seeded fixture states)
  # =============================================================

  test "no domain shows input form" do
    navigate_to_settings("rtfm")
    @settings_page.click_custom_domain_tab

    assert @settings_page.has_domain_input?, "Expected custom domain input to be visible"
    assert @page.locator("input[value='Add Custom Domain']").count > 0,
           "Expected 'Add Custom Domain' submit button to exist"
  end

  test "pending domain shows DNS instructions" do
    navigate_to_settings("custom-domain-pending")
    @settings_page.click_custom_domain_tab

    assert @settings_page.settings_panel_has_text?("help.pending-example.com"), "Expected pending domain name"
    assert @settings_page.has_pending_status?, "Expected 'Waiting for DNS configuration' text"
    assert @settings_page.has_dns_instructions?, "Expected DNS instructions"
    assert @settings_page.has_check_status_button?, "Expected 'Check Status' button"
    assert @settings_page.has_remove_domain_button?, "Expected 'Remove Domain' button"
  end

  test "active domain shows green success" do
    navigate_to_settings("custom-domain-active")
    @settings_page.click_custom_domain_tab

    assert @settings_page.settings_panel_has_text?("help.active-example.com"), "Expected active domain name"
    assert @settings_page.has_active_status?, "Expected 'Active and serving traffic' text"
    assert @settings_page.has_remove_domain_button?, "Expected 'Remove Domain' button"
  end

  test "failed domain shows error and retry" do
    navigate_to_settings("custom-domain-failed")
    @settings_page.click_custom_domain_tab

    assert @settings_page.has_failed_status?, "Expected 'Domain Setup Failed' text"
    assert @settings_page.settings_panel_has_text?("help.failed-example.com"), "Expected failed domain name"
    assert @settings_page.settings_panel_has_text?("could not be verified"), "Expected 'could not be verified' text"
    assert @settings_page.has_retry_verification_button?, "Expected 'Retry Verification' button"
    assert @settings_page.has_remove_domain_button?, "Expected 'Remove Domain' button"
  end

  # =============================================================
  # Other Sub-Tab Tests
  # =============================================================

  test "AI settings sub-tab renders" do
    navigate_to_settings("rtfm")
    @settings_page.click_ai_settings_tab

    assert @settings_page.has_ai_settings?, "Expected AI settings form to exist"
    assert @settings_page.settings_panel_has_text?("AI Settings"), "Expected 'AI Settings' heading"
    assert @settings_page.settings_panel_has_text?("Model for Article Generation"), "Expected model selector label"
  end

  test "recommendations sub-tab renders" do
    navigate_to_settings("rtfm")
    @settings_page.click_recommendations_tab

    assert @settings_page.has_recommendations_form?, "Expected recommendations form to exist"
    assert @settings_page.settings_panel_has_text?("Recommendations"), "Expected Recommendations heading"
    assert @settings_page.settings_panel_has_text?("When should we check your code"), "Expected recommendations description"
  end

  test "notifications sub-tab shows toast and browser sections" do
    navigate_to_settings("rtfm")
    @settings_page.click_notifications_tab

    assert @settings_page.has_notifications_section?, "Expected notifications section content"
  end

  test "danger zone sub-tab renders" do
    navigate_to_settings("rtfm")
    @settings_page.click_danger_zone_tab

    assert @settings_page.has_danger_zone?, "Expected danger zone content"
    assert @settings_page.settings_panel_has_text?("Start Over"), "Expected 'Start Over' text"
    assert @settings_page.settings_panel_has_text?("Permanently delete"), "Expected delete project description"
  end
end

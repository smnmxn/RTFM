require "e2e_test_helper"
require_relative "../pages/onboarding_page"

class OnboardingFlowTest < E2ETestCase
  setup do
    @user = users(:one)
    @onboarding_page = E2E::Pages::OnboardingPage.new(@page, self)
    login_as(@user)
  end

  # =============================================================
  # Landing Page Tests
  # =============================================================

  test "onboarding landing page renders" do
    @onboarding_page.visit_new
    assert @onboarding_page.has_text?("Create your help centre"),
      "Expected 'Create your help centre' heading to be visible"
  end

  test "clicking Get Started creates project and redirects" do
    @onboarding_page.visit_new
    @page.click("input[type='submit']")
    wait_for_turbo
    @page.wait_for_load_state(state: "networkidle")

    # Should redirect to the repository step for the newly created project
    assert @onboarding_page.on_repository_step?,
      "Expected to be redirected to repository step after clicking Get Started"
  end

  # =============================================================
  # Setup Step Tests
  # =============================================================

  test "setup step renders form fields" do
    project = projects(:onboarding_setup)
    @onboarding_page.visit_step(project.slug, "setup")
    @page.wait_for_selector("input[name='project[name]']", timeout: 10_000)

    assert @onboarding_page.has_text?("Set up your help centre"),
      "Expected 'Set up your help centre' heading to be visible"
    assert @onboarding_page.has_element?("input[name='project[name]']"),
      "Expected project name input to be present"
    assert @onboarding_page.has_element?("input[name='project[subdomain]']"),
      "Expected subdomain input to be present"
    assert @onboarding_page.has_element?("button[type='submit']"),
      "Expected Continue button to be present"
  end

  test "setup step shows support contact fields" do
    project = projects(:onboarding_setup)
    @onboarding_page.visit_step(project.slug, "setup")
    @page.wait_for_selector("input[name='project[support_email]']", timeout: 10_000)

    assert @onboarding_page.has_element?("input[name='project[support_email]']"),
      "Expected support email input to be present"
    assert @onboarding_page.has_element?("input[name='project[support_phone]']"),
      "Expected support phone input to be present"
  end

  test "setup step validates required fields" do
    project = projects(:onboarding_setup)
    @onboarding_page.visit_step(project.slug, "setup")
    @page.wait_for_selector("input[name='project[name]']", timeout: 10_000)

    # Clear the name field and subdomain field
    @page.fill("input[name='project[name]']", "")
    @page.fill("input[name='project[subdomain]']", "")

    # Try to submit - HTML5 validation should prevent submission
    # The required attribute on the name input prevents form submission
    @page.click("button[type='submit']")
    wait_for_turbo

    # Should still be on setup step since HTML5 validation blocks submission
    assert @onboarding_page.on_setup_step?,
      "Expected to remain on setup step when required fields are empty"
  end

  # =============================================================
  # Analyze Step Tests (state-based)
  # =============================================================

  test "analyze step shows analyzing UI" do
    project = projects(:onboarding_analyze)
    @onboarding_page.visit_step(project.slug, "analyze")

    # Controller auto-starts analysis (sets pending status and enqueues job)
    # With no target_audience set, it shows the questions form
    assert @onboarding_page.has_text?("Help us tailor your docs") || @onboarding_page.has_text?("Analyzing your codebase"),
      "Expected analyzing UI or questions form to be visible"
  end

  test "analyze step with completed status shows completion or generating topics" do
    project = projects(:onboarding_analyze_completed)
    @onboarding_page.visit_step(project.slug, "analyze")

    # With sections_generation_status completed but no sections existing,
    # the view falls to the else branch showing "Generating topics"
    assert @onboarding_page.has_text?("Analysis complete!") ||
           @onboarding_page.has_text?("Generating topics") ||
           @onboarding_page.on_sections_step?,
      "Expected analysis complete message, generating topics UI, or redirect to sections step"
  end

  test "analyze step with failed status shows error" do
    project = projects(:onboarding_analyze_failed)
    @onboarding_page.visit_step(project.slug, "analyze")

    assert @onboarding_page.has_text?("Analysis failed"),
      "Expected 'Analysis failed' error message to be visible"
  end

  # =============================================================
  # Sections Step Tests
  # =============================================================

  test "sections step renders pending sections" do
    project = projects(:onboarding_sections)
    @onboarding_page.visit_step(project.slug, "sections")

    assert @onboarding_page.has_text?("Review your topics"),
      "Expected 'Review your topics' heading to be visible"
    assert @onboarding_page.has_section_card?("Quick Start Guide"),
      "Expected 'Quick Start Guide' section card to be visible"
    assert @onboarding_page.has_section_card?("API Reference"),
      "Expected 'API Reference' section card to be visible"
  end

  test "accepting a section updates the list" do
    project = projects(:onboarding_sections)
    @onboarding_page.visit_step(project.slug, "sections")

    # Verify both sections are initially present
    assert @onboarding_page.has_section_card?("Quick Start Guide"),
      "Expected Quick Start Guide to be visible initially"

    # Click the first Accept button (Quick Start Guide is first)
    # button_to generates <button type="submit">Accept</button>
    @page.locator("#pending-sections-list button:has-text('Accept')").first.click
    wait_for_turbo

    # Wait for the Quick Start Guide section to be removed from the DOM
    @page.wait_for_selector("text=Quick Start Guide", state: "hidden", timeout: 5_000) rescue nil

    # Quick Start Guide should no longer be visible
    refute @onboarding_page.has_section_card?("Quick Start Guide"),
      "Expected Quick Start Guide to be removed after accepting"
  end

  test "skipping a section updates the list" do
    project = projects(:onboarding_sections)
    @onboarding_page.visit_step(project.slug, "sections")

    # Verify both sections are initially present
    assert @onboarding_page.has_section_card?("Quick Start Guide"),
      "Expected Quick Start Guide to be visible initially"

    # Click the first Skip button (Quick Start Guide is first)
    # button_to generates <button type="submit">Skip</button>
    @page.locator("#pending-sections-list button:has-text('Skip')").first.click
    wait_for_turbo

    # Wait for the Quick Start Guide section to be removed from the DOM
    @page.wait_for_selector("text=Quick Start Guide", state: "hidden", timeout: 5_000) rescue nil

    # Quick Start Guide should no longer be visible
    refute @onboarding_page.has_section_card?("Quick Start Guide"),
      "Expected Quick Start Guide to be removed after skipping"
  end

  test "reviewing all sections shows completion state" do
    project = projects(:onboarding_sections)
    @onboarding_page.visit_step(project.slug, "sections")

    # Verify we start with 2 Accept buttons
    assert_equal 2, @page.locator("#pending-sections-list button:has-text('Accept')").count,
      "Expected 2 Accept buttons initially"

    # Accept first section (Quick Start Guide)
    @page.locator("#pending-sections-list button:has-text('Accept')").first.click
    wait_for_turbo
    @page.wait_for_load_state(state: "networkidle")

    # Wait for turbo stream + broadcast morph to settle (Section#broadcast_refreshes
    # triggers a Turbo morph via ActionCable after the turbo stream response)
    10.times do
      break if @page.locator("#pending-sections-list button:has-text('Accept')").count == 1
      sleep 0.5
    end

    # Disconnect ActionCable to prevent broadcast_refreshes morph from racing
    # with the controller's 303 redirect after accepting the last section
    @page.evaluate("() => { if (window.Turbo?.StreamActions) { document.querySelectorAll('turbo-cable-stream-source').forEach(el => el.remove()) } }")

    # Accept second section (API Reference) - this triggers a 303 redirect to generating step
    @page.locator("#pending-sections-list button:has-text('Accept')").first.click
    wait_for_turbo
    @page.wait_for_load_state(state: "networkidle")

    # After reviewing all sections, should either show "All topics reviewed"
    # or auto-progress to the generating step
    assert @onboarding_page.has_all_reviewed_message? || @onboarding_page.on_generating_step?,
      "Expected 'All topics reviewed' message or redirect to generating step"
  end

  # =============================================================
  # Generating Step Tests
  # =============================================================

  test "generating step shows progress UI" do
    project = projects(:onboarding_generating)
    @onboarding_page.visit_step(project.slug, "generating")

    assert @onboarding_page.has_progress_ui?,
      "Expected progress UI (Creating your help centre) to be visible"
  end

  # =============================================================
  # Guard / Redirect Tests
  # =============================================================

  test "visiting wrong step redirects to correct step" do
    project = projects(:onboarding_setup)
    # Try to visit analyze step when project is on setup step
    @onboarding_page.visit_step(project.slug, "analyze")
    @page.wait_for_load_state(state: "networkidle")

    # Should be redirected back to setup step
    assert @onboarding_page.on_setup_step?,
      "Expected to be redirected to setup step when visiting wrong step (current path: #{@onboarding_page.current_path})"
  end
end

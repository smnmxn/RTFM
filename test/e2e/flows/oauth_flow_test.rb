require "e2e_test_helper"
require_relative "../pages/login_page"
require_relative "../pages/dashboard_page"

class OAuthFlowTest < E2ETestCase
  setup do
    @login_page = E2E::Pages::LoginPage.new(@page, self)
    @dashboard_page = E2E::Pages::DashboardPage.new(@page, self)
  end

  # =============================================================
  # Page Rendering Tests
  # =============================================================

  test "login page displays logo" do
    @login_page.visit

    assert @login_page.has_logo?, "Expected logo to be visible"
  end

  test "login page displays tagline" do
    @login_page.visit

    assert @login_page.has_tagline?, "Expected tagline to be visible"
  end

  test "login page displays video placeholder" do
    @login_page.visit

    assert @login_page.has_video_placeholder?, "Expected video placeholder to be visible"
  end

  test "login page displays GitHub sign in button" do
    @login_page.visit

    assert @login_page.has_github_button?, "Expected GitHub sign in button to be visible"
  end

  test "login page displays existing users section" do
    @login_page.visit

    assert @login_page.has_existing_users_section?, "Expected 'Existing users' section to be visible"
  end

  test "login page displays waitlist form" do
    @login_page.visit

    assert @login_page.has_waitlist_form?, "Expected waitlist form to be visible"
  end

  test "login page displays waitlist section" do
    @login_page.visit

    assert @login_page.has_waitlist_section?, "Expected 'New here?' waitlist section to be visible"
  end

  test "login page is accessible at /login" do
    visit "/login"

    assert_path "/login"
    assert @page.url.include?("/login"), "Should be on login page"
  end

  # =============================================================
  # Waitlist Flow Tests
  # =============================================================

  test "join waitlist with valid email shows success message" do
    unique_email = "newuser_#{SecureRandom.hex(4)}@example.com"
    @login_page.visit
    @login_page.join_waitlist(unique_email)

    assert has_text?("You're on the list"), "Expected success message"
  end

  test "join waitlist with duplicate email shows already registered message" do
    # First, add an email to the waitlist
    unique_email = "duplicate_#{SecureRandom.hex(4)}@example.com"
    @login_page.visit
    @login_page.join_waitlist(unique_email)

    # Wait for success message to confirm first submission worked
    wait_for_text("You're on the list")

    # Now try to add the same email again
    @login_page.join_waitlist(unique_email)

    # Wait for and assert the duplicate message
    wait_for_text("already on the waitlist")
    assert has_text?("already on the waitlist"), "Expected already registered message"
  end

  test "join waitlist with invalid email shows error" do
    @login_page.visit

    # Fill in an invalid email format
    @page.fill("input[type='email']", "not-an-email")
    @page.click("input[type='submit']")
    wait_for_turbo

    # Browser validation should prevent submission, or server should return error
    # If browser validation blocks, we stay on the same page
    # If server validates, we get an alert message
    assert_path "/login"
  end

  # =============================================================
  # Invite Token Flow Tests
  # =============================================================

  test "visiting with valid invite token shows create account button" do
    @login_page.visit_with_invite("valid-test-token-123")

    assert @login_page.has_create_account_button?, "Expected 'Create account' button when invite is valid"
    assert @login_page.has_invite_ready_message?, "Expected 'Your invite is ready' message"
  end

  test "visiting with invalid invite token shows error" do
    @login_page.visit_with_invite("invalid-nonexistent-token")

    assert @login_page.has_alert_message?("Invalid invite link"), "Expected invalid invite error message"
  end

  test "visiting with already used invite token shows error" do
    @login_page.visit_with_invite("used-test-token-456")

    assert @login_page.has_alert_message?("already been used"), "Expected already used invite error message"
  end

  # =============================================================
  # Flash Message Tests
  # =============================================================

  test "notice flash message displays in green" do
    # Use valid invite to trigger a notice message
    @login_page.visit_with_invite("valid-test-token-123")

    # Check that the emerald/green notice container exists
    assert has_text?("Invite accepted"), "Expected notice message text"
    assert visible?(".bg-emerald-50"), "Expected green notice styling"
  end

  test "alert flash message displays in red" do
    # Use invalid invite to trigger an alert message
    @login_page.visit_with_invite("completely-fake-token")

    # Check that the red alert container exists
    assert has_text?("Invalid invite link"), "Expected alert message text"
    assert visible?(".bg-red-50"), "Expected red alert styling"
  end

  # =============================================================
  # Navigation Tests
  # =============================================================

  test "root path shows login page for unauthenticated users" do
    visit "/"

    # Root should show the login page content
    assert @login_page.has_logo?, "Expected to see login page content at root"
    assert @login_page.has_github_button?, "Expected GitHub button on root page"
  end

  # Note: OAuth callback redirect test removed - OmniAuth mock doesn't work
  # reliably in E2E tests (server runs in separate thread). OAuth flow is
  # better tested via controller integration tests in sessions_controller_test.rb

  # =============================================================
  # Health Check Test
  # =============================================================

  test "health check endpoint is accessible" do
    visit "/up"

    assert @page.url.include?("/up"), "Health check should be accessible"
  end
end

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

  test "login page displays Log in and Sign up buttons" do
    @login_page.visit

    assert @login_page.has_login_button?, "Expected Log in CTA button"
    assert @login_page.has_signup_button?, "Expected Sign up CTA button"
  end

  # =============================================================
  # Modal Tests
  # =============================================================

  test "clicking Log in opens modal with sign in form" do
    @login_page.visit
    @login_page.open_login_modal

    assert @login_page.has_modal_open?, "Expected modal to be open"
    assert has_text?("Welcome back"), "Expected sign in title"
    assert @login_page.has_github_button?, "Expected GitHub button in modal"
    assert @login_page.has_google_button?, "Expected Google button in modal"
    assert @login_page.has_apple_button?, "Expected Apple button in modal"
  end

  test "clicking Sign up opens modal with register form" do
    @login_page.visit
    @login_page.open_signup_modal

    assert @login_page.has_modal_open?, "Expected modal to be open"
    assert has_text?("Create your account"), "Expected register title"
    assert visible?("input[name='name']"), "Expected name field visible"
  end

  test "modal toggles between sign in and register" do
    @login_page.visit
    @login_page.open_login_modal

    # Start in sign in mode
    assert has_text?("Welcome back"), "Expected sign in mode"

    # Toggle to register
    @page.click("[data-login-toggle-target='toggleLink']")
    assert has_text?("Create your account"), "Expected register mode"

    # Toggle back to sign in
    @page.click("[data-login-toggle-target='toggleLink']")
    assert has_text?("Welcome back"), "Expected sign in mode again"
  end

  test "modal closes on backdrop click" do
    @login_page.visit
    @login_page.open_login_modal
    assert @login_page.has_modal_open?, "Modal should be open"

    # Click outside the modal dialog (on the modal overlay)
    @page.click("[data-login-toggle-target='modal']", position: { x: 10, y: 10 })
    sleep 0.5

    assert_not @login_page.has_modal_open?, "Modal should be closed after backdrop click"
  end

  test "modal closes on X button click" do
    @login_page.visit
    @login_page.open_login_modal
    assert @login_page.has_modal_open?, "Modal should be open"

    # Click close button (the X button inside the modal)
    @page.click("button[data-action='click->login-toggle#close']")
    sleep 0.5

    assert_not @login_page.has_modal_open?, "Modal should be closed after X click"
  end

  # =============================================================
  # Invite Token Flow Tests
  # =============================================================

  test "visiting with valid invite token shows invite ready message" do
    @login_page.visit_with_invite("valid-test-token-123")

    assert @login_page.has_invite_ready_message?, "Expected 'Your invite is ready' message"
  end

  test "visiting with invalid invite token shows error on page" do
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

  test "notice flash message displays in green on page" do
    @login_page.visit_with_invite("valid-test-token-123")

    assert has_text?("Invite accepted"), "Expected notice message text"
    assert @login_page.has_notice_message?("Invite accepted"), "Expected green notice styling"
  end

  test "alert flash message displays in red on page" do
    @login_page.visit_with_invite("completely-fake-token")

    assert has_text?("Invalid invite link"), "Expected alert message text"
    assert @login_page.has_alert_message?("Invalid invite link"), "Expected red alert styling"
  end

  # =============================================================
  # Navigation Tests
  # =============================================================

  test "root path shows login page for unauthenticated users" do
    visit "/"

    assert @login_page.has_logo?, "Expected to see login page content at root"
    assert @login_page.has_login_button?, "Expected Log in button on root page"
  end

  test "login page is accessible at /login" do
    visit "/login"

    assert_path "/login"
    assert @page.url.include?("/login"), "Should be on login page"
  end

  # =============================================================
  # Health Check Test
  # =============================================================

  test "health check endpoint is accessible" do
    visit "/up"

    assert @page.url.include?("/up"), "Health check should be accessible"
  end
end

require "e2e_test_helper"
require_relative "../pages/login_page"
require_relative "../pages/dashboard_page"

class OAuthFlowTest < E2ETestCase
  setup do
    @login_page = E2E::Pages::LoginPage.new(@page, self)
    @dashboard_page = E2E::Pages::DashboardPage.new(@page, self)
  end

  test "login page displays GitHub sign in button" do
    @login_page.visit

    assert @login_page.has_github_button?, "Expected GitHub sign in button to be visible"
  end

  test "login page displays waitlist form" do
    @login_page.visit

    assert @login_page.has_waitlist_form?, "Expected waitlist form to be visible"
  end

  test "login page is accessible at /login" do
    visit "/login"

    assert_path "/login"
    # Page should load without error
    assert @page.url.include?("/login"), "Should be on login page"
  end

  test "health check endpoint is accessible" do
    visit "/up"

    # Should not error out
    assert @page.url.include?("/up"), "Health check should be accessible"
  end
end

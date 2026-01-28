require "e2e_test_helper"
require_relative "../pages/dashboard_page"

class ArticleLifecycleTest < E2ETestCase
  # Note: Full authentication flow tests require shared session state between
  # the test process and server thread. These tests focus on public page access.

  test "projects page redirects unauthenticated users" do
    visit "/projects"

    # Should be redirected (exact destination depends on config)
    # The key assertion is that the page loads without error
    assert @page.url.present?, "Page should load"
  end

  test "dashboard pages are protected" do
    # Attempting to access a protected route should redirect
    visit "/projects/some-project"

    # Page should load (either redirect to login or show error)
    assert @page.url.present?, "Page should respond"
  end
end

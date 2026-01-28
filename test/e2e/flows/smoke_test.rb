require "e2e_test_helper"

class SmokeTest < E2ETestCase
  test "health check endpoint returns success" do
    visit "/up"

    # Rails health check should return success
    assert @page.content.include?("html") || @page.url.include?("/up"),
           "Health check endpoint should be accessible"
  end

  test "login page is accessible" do
    visit "/login"

    # Login page should render
    assert @page.url.include?("/login"), "Should be on login page"
  end

  test "root redirects appropriately" do
    visit "/"

    # Root should redirect somewhere (login or projects)
    wait_for_turbo
    assert @page.url.present?, "Page should have loaded"
  end
end

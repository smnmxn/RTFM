require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "dashboard requires authentication" do
    get dashboard_path
    assert_redirected_to login_path
  end

  test "dashboard shows user projects" do
    sign_in_as(@user)
    get dashboard_path
    assert_response :success
    assert_select "h2", text: /Your Projects/
  end

  test "dashboard shows current user info" do
    sign_in_as(@user)
    get dashboard_path
    assert_select "span", text: @user.name
  end
end

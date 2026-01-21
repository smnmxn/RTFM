require "test_helper"

class ProjectsIndexTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "projects index requires authentication" do
    get projects_path
    assert_redirected_to login_path
  end

  test "projects index always shows list regardless of project count" do
    sign_in_as(@user)
    # user :one has two projects (one and one_second)
    get projects_path
    assert_response :success
    assert_select "h2", text: /Your Projects/
  end

  test "projects index shows current user info" do
    sign_in_as(@user)
    get projects_path
    assert_select "span", text: @user.name
  end

  test "projects index shows list even with one project" do
    sign_in_as(@user)
    projects(:one_second).destroy
    get projects_path
    assert_response :success
    assert_select "h2", text: /Your Projects/
  end

  test "projects index shows empty state when user has no projects" do
    sign_in_as(@user)
    @user.projects.destroy_all
    get projects_path
    assert_response :success
    assert_select "h3", text: /No projects yet/
  end
end

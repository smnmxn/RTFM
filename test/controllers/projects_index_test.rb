require "test_helper"

class ProjectsIndexTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    use_app_subdomain
  end

  test "projects index requires authentication" do
    get projects_path
    assert_response :redirect
  end

  test "projects index renders for authenticated user" do
    sign_in_as(@user)
    get projects_path
    assert_response :success
  end

  test "projects index shows current user info" do
    sign_in_as(@user)
    get projects_path
    assert_select "span", text: @user.name
  end

  test "projects index renders with one project" do
    sign_in_as(@user)
    projects(:one_second).destroy
    get projects_path
    assert_response :success
  end

  test "projects index renders with no projects" do
    # Create a fresh user with no projects to avoid destroy callback issues
    empty_user = User.create!(
      email: "empty@example.com",
      name: "Empty User",
      github_uid: "gh_empty_#{SecureRandom.hex(4)}",
      github_username: "emptyuser",
      github_token: "token_empty"
    )
    sign_in_as(empty_user)
    get projects_path
    assert_response :success
  end
end

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)

    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: "new_github_uid",
      info: {
        email: "newuser@example.com",
        name: "New User",
        nickname: "newuser"
      },
      credentials: {
        token: "new_github_token"
      }
    })
  end

  test "login page renders" do
    get login_path
    assert_response :success
    assert_select "span", text: /Sign in with GitHub/
  end

  test "login page redirects to single project if already logged in with one project" do
    sign_in_as(@user)
    projects(:one_second).destroy  # Leave only one project
    get login_path
    assert_redirected_to project_path(projects(:one))
  end

  test "login page redirects to projects list if already logged in with multiple projects" do
    sign_in_as(@user)
    get login_path
    assert_redirected_to projects_path
  end

  test "successful OAuth creates new user and redirects to onboarding" do
    assert_difference "User.count", 1 do
      post "/auth/github"
      follow_redirect!
    end

    # New users (no projects) are redirected to onboarding
    assert_redirected_to new_onboarding_project_path
  end

  test "successful OAuth for existing user with multiple projects redirects to projects list" do
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: @user.github_uid,
      info: {
        email: @user.email,
        name: "Updated Name",
        nickname: @user.github_username
      },
      credentials: {
        token: "updated_token"
      }
    })

    assert_no_difference "User.count" do
      post "/auth/github"
    end

    follow_redirect!
    @user.reload
    assert_equal "updated_token", @user.github_token
    assert_equal "Updated Name", @user.name
    assert_redirected_to projects_path
  end

  test "successful OAuth for existing user with one project redirects to that project" do
    projects(:one_second).destroy  # Leave only one project

    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: @user.github_uid,
      info: {
        email: @user.email,
        name: @user.name,
        nickname: @user.github_username
      },
      credentials: {
        token: "updated_token"
      }
    })

    post "/auth/github"
    follow_redirect!
    assert_redirected_to project_path(projects(:one))
  end

  test "OAuth failure redirects to login with error message" do
    get "/auth/failure", params: { message: "access_denied" }
    assert_redirected_to login_path
    follow_redirect!
    assert_select "div", text: /access_denied/
  end

  test "logout clears session and redirects" do
    sign_in_as(@user)
    delete logout_path
    assert_redirected_to root_path

    # Verify logged out
    get projects_path
    assert_redirected_to login_path
  end
end

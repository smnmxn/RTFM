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

  test "login page redirects if already logged in with one project" do
    sign_in_as(@user)
    projects(:one_second).destroy

    get login_path
    assert_response :redirect
  end

  test "login page redirects if already logged in with multiple projects" do
    sign_in_as(@user)
    get login_path
    assert_response :redirect
  end

  test "successful OAuth creates new user with valid invite" do
    invite = Invite.create!(token: "fresh-test-token-#{SecureRandom.hex(4)}")
    use_app_subdomain

    # Visit invite URL to set session[:invite_token]
    get "/invite/#{invite.token}"

    assert_difference "User.count", 1 do
      post "/auth/github"
      follow_redirect!
    end

    # New users (no projects) are redirected to onboarding
    assert_response :redirect
  end

  test "successful OAuth without invite rejects new user" do
    use_app_subdomain

    assert_no_difference "User.count" do
      post "/auth/github"
      follow_redirect!
    end

    assert_response :redirect
  end

  test "successful OAuth for existing user updates credentials" do
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
    assert_response :redirect
  end

  test "successful OAuth for existing user with one project redirects to that project" do
    @user.projects.where.not(id: projects(:one).id).destroy_all

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
    assert_response :redirect
    assert_match(/projects\/rtfm/, response.location)
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
    assert_response :redirect

    # Verify logged out by accessing a protected route
    use_app_subdomain
    get projects_path
    assert_response :redirect
  end
end

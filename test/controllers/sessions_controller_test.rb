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

  # --- Login page ---

  test "login page renders with CTA buttons" do
    get login_path
    assert_response :success
    assert_select "button", text: /Log in/
    assert_select "button", text: /Sign up/
  end

  test "login page contains auth modal with OAuth buttons" do
    get login_path
    assert_response :success
    assert_select "span", text: /Continue with GitHub/
    assert_select "span", text: /Continue with Google/
    assert_select "span", text: /Continue with Apple/
  end

  test "login page contains email/password form in modal" do
    get login_path
    assert_response :success
    assert_select "input[name='email'][type='email']"
    assert_select "input[name='password'][type='password']"
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

  # --- GitHub OAuth ---

  test "successful OAuth creates new user with valid invite" do
    invite = Invite.create!(token: "fresh-test-token-#{SecureRandom.hex(4)}")
    use_app_subdomain

    get "/invite/#{invite.token}"

    assert_difference "User.count", 1 do
      post "/auth/github"
      follow_redirect!
    end

    assert_response :redirect
  end

  test "successful OAuth without invite shows invite-only message when REQUIRE_INVITE is set" do
    ENV["REQUIRE_INVITE"] = "true"
    use_app_subdomain

    assert_no_difference "User.count" do
      post "/auth/github"
      follow_redirect!
    end

    assert_redirected_to login_path
    assert_match /invite-only/, flash[:alert]
  ensure
    ENV.delete("REQUIRE_INVITE")
  end

  test "successful OAuth without invite creates user when REQUIRE_INVITE is not set" do
    use_app_subdomain

    assert_difference "User.count", 1 do
      post "/auth/github"
      follow_redirect!
    end

    assert_response :redirect
  end

  test "successful OAuth for existing user logs them in" do
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: user_identities(:one_github).uid,
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
    assert_equal "updated_token", user_identities(:one_github).reload.token
    assert_response :redirect
  end

  test "successful OAuth for existing user with one project redirects to that project" do
    @user.projects.where.not(id: projects(:one).id).destroy_all

    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: user_identities(:one_github).uid,
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

  # --- Google OAuth ---

  test "successful Google OAuth creates new user with valid invite" do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google_new_uid",
      info: {
        email: "googleuser@example.com",
        name: "Google User",
        nickname: nil
      },
      credentials: {
        token: "google_token"
      }
    })

    invite = Invite.create!(token: "google-invite-#{SecureRandom.hex(4)}")
    use_app_subdomain
    get "/invite/#{invite.token}"

    assert_difference "User.count", 1 do
      post "/auth/google_oauth2"
      follow_redirect!
    end

    user = User.find_by(email: "googleuser@example.com")
    assert_not_nil user
    assert_equal "google_oauth2", user.user_identities.last.provider
    assert_response :redirect
  end

  test "Google OAuth auto-links to existing user by email" do
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google_autolink_uid",
      info: {
        email: @user.email,
        name: @user.name,
        nickname: nil
      },
      credentials: {
        token: "google_token"
      }
    })

    use_app_subdomain

    assert_no_difference "User.count" do
      assert_difference "UserIdentity.count", 1 do
        post "/auth/google_oauth2"
        follow_redirect!
      end
    end

    assert_equal @user, UserIdentity.find_by(provider: "google_oauth2", uid: "google_autolink_uid").user
    assert_response :redirect
  end

  # --- Email/password ---

  test "email/password login with valid credentials" do
    user = User.create!(email: "pwuser@example.com", password: "securepass123", password_confirmation: "securepass123", email_confirmed_at: Time.current)

    use_app_subdomain
    post login_with_password_path, params: { email: "pwuser@example.com", password: "securepass123" }

    assert_response :redirect
  end

  test "email/password login with unconfirmed email redirects to confirmation pending" do
    user = User.create!(email: "unconfirmed@example.com", password: "securepass123", password_confirmation: "securepass123")

    use_app_subdomain
    post login_with_password_path, params: { email: "unconfirmed@example.com", password: "securepass123" }

    assert_redirected_to confirmation_pending_path(email: "unconfirmed@example.com")
    assert_match /confirm your email/, flash[:alert]
  end

  test "email/password login with invalid password" do
    User.create!(email: "pwuser2@example.com", password: "securepass123", password_confirmation: "securepass123", email_confirmed_at: Time.current)

    post login_with_password_path, params: { email: "pwuser2@example.com", password: "wrongpassword" }

    assert_response :unprocessable_entity
    assert_select "div", text: /Invalid email or password/
  end

  test "email/password login with nonexistent email" do
    post login_with_password_path, params: { email: "nonexistent@example.com", password: "password123" }

    assert_response :unprocessable_entity
    assert_select "div", text: /Invalid email or password/
  end

  test "email registration with valid invite sends confirmation email" do
    invite = Invite.create!(token: "email-invite-#{SecureRandom.hex(4)}")
    use_app_subdomain
    get "/invite/#{invite.token}"

    assert_difference "User.count", 1 do
      post register_path, params: {
        name: "Email User",
        email: "emailuser@example.com",
        password: "securepass123",
        password_confirmation: "securepass123"
      }
    end

    user = User.find_by(email: "emailuser@example.com")
    assert_not_nil user
    assert_equal "Email User", user.name
    assert_nil user.email_confirmed_at
    assert_not_nil user.confirmation_token
    assert invite.reload.used_at.present?
    assert_redirected_to confirmation_pending_path(email: "emailuser@example.com")
  end

  test "email registration without invite shows invite-only message when REQUIRE_INVITE is set" do
    ENV["REQUIRE_INVITE"] = "true"
    use_app_subdomain

    assert_no_difference "User.count" do
      post register_path, params: {
        name: "No Invite",
        email: "noinvite@example.com",
        password: "securepass123",
        password_confirmation: "securepass123"
      }
    end

    assert_redirected_to login_path
    assert_match /invite-only/, flash[:alert]
  ensure
    ENV.delete("REQUIRE_INVITE")
  end

  test "email registration without invite creates user and redirects to confirmation pending" do
    use_app_subdomain

    assert_difference "User.count", 1 do
      post register_path, params: {
        name: "Open Signup",
        email: "opensignup@example.com",
        password: "securepass123",
        password_confirmation: "securepass123"
      }
    end

    user = User.find_by(email: "opensignup@example.com")
    assert_nil user.email_confirmed_at
    assert_not_nil user.confirmation_token
    assert_redirected_to confirmation_pending_path(email: "opensignup@example.com")
  end

  test "email registration with invalid data re-renders form" do
    invite = Invite.create!(token: "bad-reg-#{SecureRandom.hex(4)}")
    use_app_subdomain
    get "/invite/#{invite.token}"

    assert_no_difference "User.count" do
      post register_path, params: {
        name: "Bad User",
        email: "baduser@example.com",
        password: "short",
        password_confirmation: "short"
      }
    end

    assert_response :unprocessable_entity
  end

  # --- Logout ---

  test "logout clears session and redirects" do
    sign_in_as(@user)
    delete logout_path
    assert_response :redirect

    use_app_subdomain
    get projects_path
    assert_response :redirect
  end

  # --- Redirect after login ---

  test "redirects to stored path after login" do
    use_app_subdomain
    get projects_path
    assert_response :redirect

    sign_in_as(@user)
    assert_response :redirect
  end
end

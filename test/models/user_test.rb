require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user" do
    user = User.new(email: "test@example.com")
    assert user.valid?
  end

  test "requires email" do
    user = User.new(email: nil)
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "requires unique email" do
    User.create!(email: "dupe@example.com")
    user = User.new(email: "dupe@example.com")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "requires unique github_uid when present" do
    User.create!(email: "first@example.com", github_uid: "uid123")
    user = User.new(email: "second@example.com", github_uid: "uid123")
    assert_not user.valid?
    assert_includes user.errors[:github_uid], "has already been taken"
  end

  test "allows nil github_uid" do
    user = User.new(email: "test@example.com", github_uid: nil)
    assert user.valid?
  end

  test "has many projects" do
    user = users(:one)
    assert_respond_to user, :projects
  end

  test "has many user_identities" do
    user = users(:one)
    assert_respond_to user, :user_identities
    assert_includes user.user_identities, user_identities(:one_github)
  end

  test "has_secure_password with validations: false allows OAuth-only users" do
    user = User.new(email: "oauth_only@example.com")
    assert user.valid?
    assert_nil user.password_digest
  end

  test "validates password length when password_digest present" do
    user = User.new(email: "pw@example.com", password: "short", password_confirmation: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "allows valid password" do
    user = User.new(email: "pw@example.com", password: "securepass123", password_confirmation: "securepass123")
    assert user.valid?
  end

  test "authenticate works with password" do
    user = User.create!(email: "pw@example.com", password: "securepass123", password_confirmation: "securepass123")
    assert user.authenticate("securepass123")
    assert_not user.authenticate("wrongpassword")
  end

  test "find_from_omniauth finds user by identity" do
    user = users(:one)
    auth = OmniAuth::AuthHash.new({
      provider: "github",
      uid: user_identities(:one_github).uid,
      info: { email: user.email, name: user.name, nickname: user.github_username },
      credentials: { token: "updated_token" }
    })

    found = User.find_from_omniauth(auth)
    assert_equal user, found
    assert_equal "updated_token", user_identities(:one_github).reload.token
  end

  test "find_from_omniauth auto-links by email" do
    user = users(:one)
    auth = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google_new_uid",
      info: { email: user.email, name: user.name, nickname: nil },
      credentials: { token: "google_token" }
    })

    assert_difference "UserIdentity.count", 1 do
      found = User.find_from_omniauth(auth)
      assert_equal user, found
    end

    identity = user.user_identities.find_by(provider: "google_oauth2")
    assert_equal "google_new_uid", identity.uid
  end

  test "find_from_omniauth returns nil for unknown user" do
    auth = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "unknown_uid",
      info: { email: "unknown@example.com", name: "Unknown", nickname: nil },
      credentials: { token: "token" }
    })

    assert_nil User.find_from_omniauth(auth)
  end

  test "create_from_omniauth creates user with identity" do
    auth = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google_brand_new",
      info: { email: "brand_new_google@example.com", name: "Google User", nickname: nil },
      credentials: { token: "google_token" }
    })

    assert_difference [ "User.count", "UserIdentity.count" ], 1 do
      user = User.create_from_omniauth!(auth)
      assert_equal "brand_new_google@example.com", user.email
      assert_equal "Google User", user.name
    end
  end

  test "create_from_omniauth backfills github columns for github provider" do
    auth = OmniAuth::AuthHash.new({
      provider: "github",
      uid: "new_gh_uid",
      info: { email: "brand_new@example.com", name: "Brand New", nickname: "brandnew" },
      credentials: { token: "brand_new_token" }
    })

    user = User.create_from_omniauth!(auth)
    assert_equal "new_gh_uid", user.github_uid
    assert_equal "brand_new_token", user.github_token
    assert_equal "brandnew", user.github_username
  end

  test "find_or_create_from_omniauth creates new user" do
    auth = OmniAuth::AuthHash.new({
      provider: "github",
      uid: "new_uid_123",
      info: {
        email: "brand_new@example.com",
        name: "Brand New",
        nickname: "brandnew"
      },
      credentials: {
        token: "brand_new_token"
      }
    })

    assert_difference "User.count", 1 do
      user = User.find_or_create_from_omniauth(auth)
      assert_equal "brand_new@example.com", user.email
      assert_equal "Brand New", user.name
    end
  end

  test "find_or_create_from_omniauth updates existing user" do
    existing = users(:one)
    original_id = existing.id

    auth = OmniAuth::AuthHash.new({
      provider: "github",
      uid: existing.github_uid,
      info: {
        email: existing.email,
        name: "Updated Name",
        nickname: existing.github_username
      },
      credentials: {
        token: "refreshed_token"
      }
    })

    assert_no_difference "User.count" do
      user = User.find_or_create_from_omniauth(auth)
      assert_equal original_id, user.id
      assert_equal "refreshed_token", user.user_identities.find_by(provider: "github").token
    end
  end
end

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
      assert_equal "new_uid_123", user.github_uid
      assert_equal "brand_new@example.com", user.email
      assert_equal "Brand New", user.name
      assert_equal "brandnew", user.github_username
      assert_equal "brand_new_token", user.github_token
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
      assert_equal "Updated Name", user.name
      assert_equal "refreshed_token", user.github_token
    end
  end
end

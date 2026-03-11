require "test_helper"

class UserIdentityTest < ActiveSupport::TestCase
  test "valid identity" do
    identity = UserIdentity.new(user: users(:one), provider: "google_oauth2", uid: "google_123")
    assert identity.valid?
  end

  test "requires provider" do
    identity = UserIdentity.new(user: users(:one), provider: nil, uid: "123")
    assert_not identity.valid?
    assert_includes identity.errors[:provider], "can't be blank"
  end

  test "requires uid" do
    identity = UserIdentity.new(user: users(:one), provider: "github", uid: nil)
    assert_not identity.valid?
    assert_includes identity.errors[:uid], "can't be blank"
  end

  test "requires valid provider" do
    identity = UserIdentity.new(user: users(:one), provider: "twitter", uid: "123")
    assert_not identity.valid?
    assert_includes identity.errors[:provider], "is not included in the list"
  end

  test "uid must be unique per provider" do
    identity = UserIdentity.new(user: users(:two), provider: "github", uid: user_identities(:one_github).uid)
    assert_not identity.valid?
    assert_includes identity.errors[:uid], "has already been taken"
  end

  test "same uid can exist for different providers" do
    identity = UserIdentity.new(user: users(:one), provider: "google_oauth2", uid: user_identities(:one_github).uid)
    assert identity.valid?
  end

  test "belongs to user" do
    identity = user_identities(:one_github)
    assert_equal users(:one), identity.user
  end
end

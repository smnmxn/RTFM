require "test_helper"

class BitbucketConnectionTest < ActiveSupport::TestCase
  test "valid connection" do
    connection = bitbucket_connections(:one)
    assert connection.valid?
  end

  test "requires workspace_slug" do
    connection = BitbucketConnection.new(
      user: users(:one),
      workspace_slug: nil,
      access_token: "token",
      refresh_token: "refresh",
      token_expires_at: 2.hours.from_now
    )
    assert_not connection.valid?
    assert_includes connection.errors[:workspace_slug], "can't be blank"
  end

  test "workspace_slug must be unique per user" do
    existing = bitbucket_connections(:one)
    connection = BitbucketConnection.new(
      user: existing.user,
      workspace_slug: existing.workspace_slug,
      access_token: "token",
      refresh_token: "refresh",
      token_expires_at: 2.hours.from_now
    )
    assert_not connection.valid?
    assert_includes connection.errors[:workspace_slug], "has already been taken"
  end

  test "same workspace_slug allowed for different users" do
    connection = BitbucketConnection.new(
      user: users(:two),
      workspace_slug: bitbucket_connections(:one).workspace_slug,
      access_token: "token",
      refresh_token: "refresh",
      token_expires_at: 2.hours.from_now
    )
    assert connection.valid?
  end

  test "token_expired? returns true when token is about to expire" do
    connection = bitbucket_connections(:expired)
    assert connection.token_expired?
  end

  test "token_expired? returns false when token is fresh" do
    connection = bitbucket_connections(:one)
    assert_not connection.token_expired?
  end

  test "active scope excludes suspended connections" do
    connection = bitbucket_connections(:one)
    connection.update!(suspended_at: Time.current)
    assert_not_includes BitbucketConnection.active, connection
  end

  test "active? returns false when suspended" do
    connection = bitbucket_connections(:one)
    connection.suspended_at = Time.current
    assert_not connection.active?
  end
end

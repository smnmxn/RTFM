require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "valid project" do
    project = Project.new(user: @user, name: "Test Project", github_repo: "user/repo")
    assert project.valid?
  end

  test "requires name" do
    project = Project.new(user: @user, name: nil, github_repo: "user/repo")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "requires github_repo" do
    project = Project.new(user: @user, name: "Test", github_repo: nil)
    assert_not project.valid?
    assert_includes project.errors[:github_repo], "can't be blank"
  end

  test "validates github_repo format" do
    project = Project.new(user: @user, name: "Test", github_repo: "invalid-format")
    assert_not project.valid?
    assert_includes project.errors[:github_repo], "must be in 'owner/repo' format"
  end

  test "accepts valid github_repo formats" do
    valid_repos = ["user/repo", "org-name/repo.js", "user123/my_repo"]
    valid_repos.each do |repo|
      project = Project.new(user: @user, name: "Test", github_repo: repo)
      assert project.valid?, "Expected #{repo} to be valid"
    end
  end

  test "generates slug from name" do
    project = Project.new(user: @user, name: "My Cool Project", github_repo: "user/repo")
    project.valid?
    assert_equal "my-cool-project", project.slug
  end

  test "does not overwrite existing slug" do
    project = Project.new(user: @user, name: "My Project", slug: "custom-slug", github_repo: "user/repo")
    project.valid?
    assert_equal "custom-slug", project.slug
  end

  test "requires unique slug" do
    Project.create!(user: @user, name: "First", slug: "same-slug", github_repo: "user/first")
    project = Project.new(user: users(:two), name: "Second", slug: "same-slug", github_repo: "user/second")
    assert_not project.valid?
    assert_includes project.errors[:slug], "has already been taken"
  end

  test "validates slug format" do
    project = Project.new(user: @user, name: "Test", slug: "Invalid Slug!", github_repo: "user/repo")
    assert_not project.valid?
    assert_includes project.errors[:slug], "only allows lowercase letters, numbers, and hyphens"
  end

  test "belongs to user" do
    project = projects(:one)
    assert_equal users(:one), project.user
  end

  test "has many updates" do
    project = projects(:one)
    assert_respond_to project, :updates
  end

  test "generates webhook_secret on create" do
    project = Project.create!(user: @user, name: "New Project", github_repo: "user/new-repo")
    assert_not_nil project.webhook_secret
    assert_equal 64, project.webhook_secret.length
  end

  test "does not overwrite existing webhook_secret" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", webhook_secret: "existing_secret")
    project.save!
    assert_equal "existing_secret", project.webhook_secret
  end

  test "verify_webhook_signature returns true for valid signature" do
    project = projects(:one)
    payload = '{"test": "data"}'
    signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      project.webhook_secret,
      payload
    )

    assert project.verify_webhook_signature(payload, signature)
  end

  test "verify_webhook_signature returns false for invalid signature" do
    project = projects(:one)
    payload = '{"test": "data"}'

    assert_not project.verify_webhook_signature(payload, "sha256=invalid")
  end

  test "verify_webhook_signature returns false for nil signature" do
    project = projects(:one)
    assert_not project.verify_webhook_signature('{"test": "data"}', nil)
  end

  test "verify_webhook_signature returns false for blank webhook_secret" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo")
    project.webhook_secret = nil
    assert_not project.verify_webhook_signature('{"test": "data"}', "sha256=something")
  end
end

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

  test "allows blank github_repo" do
    project = Project.new(user: @user, name: "Test", github_repo: nil)
    assert project.valid?
  end

  test "validates github_repo format" do
    project = Project.new(user: @user, name: "Test", github_repo: "invalid-format")
    assert_not project.valid?
    assert_includes project.errors[:github_repo], "must be in 'owner/repo' format"
  end

  test "accepts valid github_repo formats" do
    valid_repos = [ "user/repo", "org-name/repo.js", "user123/my_repo" ]
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

  # Subdomain validation tests
  test "accepts valid subdomain" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "my-company")
    assert project.valid?
  end

  test "accepts subdomain with numbers" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "company123")
    assert project.valid?
  end

  test "rejects subdomain that starts with hyphen" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "-invalid")
    assert_not project.valid?
    assert project.errors[:subdomain].any? { |e| e.include?("cannot start or end with hyphen") }
  end

  test "rejects subdomain that ends with hyphen" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "invalid-")
    assert_not project.valid?
    assert project.errors[:subdomain].any? { |e| e.include?("cannot start or end with hyphen") }
  end

  test "rejects subdomain with uppercase letters" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "MyCompany")
    assert_not project.valid?
    assert project.errors[:subdomain].any?
  end

  test "rejects subdomain shorter than 3 characters" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "ab")
    assert_not project.valid?
    assert project.errors[:subdomain].any? { |e| e.include?("too short") }
  end

  test "rejects reserved subdomain www" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "www")
    assert_not project.valid?
    assert_includes project.errors[:subdomain], "is reserved and cannot be used"
  end

  test "rejects reserved subdomain admin" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "admin")
    assert_not project.valid?
    assert_includes project.errors[:subdomain], "is reserved and cannot be used"
  end

  test "rejects reserved subdomain login" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "login")
    assert_not project.valid?
    assert_includes project.errors[:subdomain], "is reserved and cannot be used"
  end

  test "rejects reserved subdomain billing" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "billing")
    assert_not project.valid?
    assert_includes project.errors[:subdomain], "is reserved and cannot be used"
  end

  test "requires unique subdomain" do
    Project.create!(user: @user, name: "First", github_repo: "user/first", subdomain: "taken")
    project = Project.new(user: users(:two), name: "Second", github_repo: "user/second", subdomain: "taken")
    assert_not project.valid?
    assert_includes project.errors[:subdomain], "has already been taken"
  end

  test "rejects subdomain that conflicts with existing slug" do
    Project.create!(user: @user, name: "First", slug: "existing-slug", github_repo: "user/first")
    project = Project.new(user: users(:two), name: "Second", github_repo: "user/second", subdomain: "existing-slug")
    assert_not project.valid?
    assert_includes project.errors[:subdomain], "conflicts with an existing project URL"
  end

  test "rejects slug that conflicts with existing subdomain" do
    Project.create!(user: @user, name: "First", github_repo: "user/first", subdomain: "taken-subdomain")
    project = Project.new(user: users(:two), name: "Second", github_repo: "user/second", slug: "taken-subdomain")
    assert_not project.valid?
    assert_includes project.errors[:slug], "conflicts with an existing subdomain"
  end

  test "allows blank subdomain" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "")
    assert project.valid?
  end

  test "effective_subdomain returns subdomain when set" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "custom", slug: "test-slug")
    assert_equal "custom", project.effective_subdomain
  end

  test "effective_subdomain falls back to slug when subdomain blank" do
    project = Project.new(user: @user, name: "Test", github_repo: "user/repo", subdomain: "", slug: "test-slug")
    assert_equal "test-slug", project.effective_subdomain
  end
end

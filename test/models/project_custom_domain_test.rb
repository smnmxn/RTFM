require "test_helper"

class ProjectCustomDomainTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    Rails.application.config.x.base_domain = "supportpages.io"
  end

  test "normalizes custom domain - removes protocol" do
    @project.custom_domain = "https://help.example.com"
    @project.valid?
    assert_equal "help.example.com", @project.custom_domain
  end

  test "normalizes custom domain - removes trailing path" do
    @project.custom_domain = "help.example.com/path"
    @project.valid?
    assert_equal "help.example.com", @project.custom_domain
  end

  test "normalizes custom domain - lowercases" do
    @project.custom_domain = "Help.Example.COM"
    @project.valid?
    assert_equal "help.example.com", @project.custom_domain
  end

  test "normalizes custom domain - strips whitespace" do
    @project.custom_domain = "  help.example.com  "
    @project.valid?
    assert_equal "help.example.com", @project.custom_domain
  end

  test "validates custom domain format - valid domain" do
    @project.custom_domain = "help.example.com"
    assert @project.valid?
  end

  test "validates custom domain format - invalid domain" do
    @project.custom_domain = "not-a-domain"
    assert_not @project.valid?
    assert_includes @project.errors[:custom_domain], "must be a valid domain name (e.g., help.example.com)"
  end

  test "rejects custom domain that is base domain" do
    @project.custom_domain = "supportpages.io"
    assert_not @project.valid?
    assert_includes @project.errors[:custom_domain], "cannot be the application domain or a subdomain of it"
  end

  test "rejects custom domain that is subdomain of base domain" do
    @project.custom_domain = "help.supportpages.io"
    assert_not @project.valid?
    assert_includes @project.errors[:custom_domain], "cannot be the application domain or a subdomain of it"
  end

  test "custom_domain_active? returns true when status is active" do
    @project.custom_domain = "help.example.com"
    @project.custom_domain_status = "active"
    assert @project.custom_domain_active?
  end

  test "custom_domain_active? returns false when domain is blank" do
    @project.custom_domain = nil
    @project.custom_domain_status = "active"
    assert_not @project.custom_domain_active?
  end

  test "custom_domain_verifying? returns true when status is verifying" do
    @project.custom_domain = "help.example.com"
    @project.custom_domain_status = "verifying"
    assert @project.custom_domain_verifying?
  end

  test "custom_domain_cname_target returns correct value" do
    assert_equal "rtfm.supportpages.io", @project.custom_domain_cname_target
  end

  test "find_by_custom_domain finds active domain" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "active"
    )
    found = Project.find_by_custom_domain("help.example.com")
    assert_equal @project, found
  end

  test "find_by_custom_domain returns nil for non-active domain" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "verifying"
    )
    found = Project.find_by_custom_domain("help.example.com")
    assert_nil found
  end

  test "find_by_custom_domain is case insensitive" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "active"
    )
    found = Project.find_by_custom_domain("HELP.EXAMPLE.COM")
    assert_equal @project, found
  end
end

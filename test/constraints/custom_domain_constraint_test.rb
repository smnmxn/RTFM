require "test_helper"

class CustomDomainConstraintTest < ActiveSupport::TestCase
  setup do
    Rails.application.config.x.base_domain = "supportpages.io"
    @project = projects(:one)
  end

  test "does not match base domain" do
    request = mock_request("supportpages.io")
    assert_not CustomDomainConstraint.matches?(request)
  end

  test "does not match subdomain of base domain" do
    request = mock_request("acme.supportpages.io")
    assert_not CustomDomainConstraint.matches?(request)
  end

  test "matches active custom domain" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "active"
    )

    request = mock_request("help.example.com")
    assert CustomDomainConstraint.matches?(request)
  end

  test "does not match pending custom domain" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "pending"
    )

    request = mock_request("help.example.com")
    assert_not CustomDomainConstraint.matches?(request)
  end

  test "does not match verifying custom domain" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "verifying"
    )

    request = mock_request("help.example.com")
    assert_not CustomDomainConstraint.matches?(request)
  end

  test "does not match non-existent domain" do
    request = mock_request("unknown.example.com")
    assert_not CustomDomainConstraint.matches?(request)
  end

  test "find_project returns project for active custom domain" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "active"
    )

    request = mock_request("help.example.com")
    found = CustomDomainConstraint.find_project(request)
    assert_equal @project, found
  end

  test "find_project is case insensitive" do
    @project.update_columns(
      custom_domain: "help.example.com",
      custom_domain_status: "active"
    )

    request = mock_request("HELP.EXAMPLE.COM")
    found = CustomDomainConstraint.find_project(request)
    assert_equal @project, found
  end

  private

  def mock_request(host)
    OpenStruct.new(host: host)
  end
end

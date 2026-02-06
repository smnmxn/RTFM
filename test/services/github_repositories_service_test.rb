require "test_helper"
require "ostruct"

class GithubRepositoriesServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @installation_counter = 0
  end

  # Helper to create an installation with fake repository data
  def create_installation(account_login:, repos: [], error: nil)
    @installation_counter += 1

    installation = GithubAppInstallation.create!(
      github_installation_id: 900000 + @installation_counter,
      account_login: account_login,
      account_type: "User",
      account_id: 800000 + @installation_counter,
      user_id: @user.id
    )

    @installations_config ||= {}
    @installations_config[installation.github_installation_id] = { repos: repos, error: error }
    installation
  end

  # Calls the service with patched GithubAppInstallation#repositories
  def call_service
    config = @installations_config || {}
    original_method = GithubAppInstallation.instance_method(:repositories)

    GithubAppInstallation.define_method(:repositories) do |**_options|
      data = config[self.github_installation_id]
      raise data[:error] if data&.dig(:error)

      repo_objects = (data&.dig(:repos) || []).map do |r|
        OpenStruct.new(
          id: r[:id] || rand(1000),
          full_name: r[:full_name],
          name: r[:full_name].split("/").last,
          owner: OpenStruct.new(login: r[:full_name].split("/").first),
          private: r[:private] || false,
          description: r[:description],
          pushed_at: Time.current,
          html_url: "https://github.com/#{r[:full_name]}"
        )
      end
      OpenStruct.new(repositories: repo_objects)
    end

    GithubRepositoriesService.new(@user).call
  ensure
    GithubAppInstallation.define_method(:repositories, original_method)
  end

  test "returns repositories from installations" do
    create_installation(
      account_login: "alice",
      repos: [
        { full_name: "alice/repo1" },
        { full_name: "alice/repo2" }
      ]
    )

    result = call_service

    assert result.success?
    assert_equal 2, result.repositories.size
  end

  test "returns empty when no installations" do
    result = call_service

    assert result.success?
    assert_empty result.repositories
  end

  test "skips installations that raise unauthorized" do
    create_installation(
      account_login: "alice",
      repos: [{ full_name: "alice/repo1" }]
    )
    create_installation(
      account_login: "bad-org",
      error: Octokit::Unauthorized.new
    )

    result = call_service

    assert result.success?
    assert_equal 1, result.repositories.size
    assert_equal "alice/repo1", result.repositories.first[:full_name]
  end

  test "skips installations that raise not found" do
    create_installation(
      account_login: "alice",
      repos: [{ full_name: "alice/repo1" }]
    )
    create_installation(
      account_login: "removed-org",
      error: Octokit::NotFound.new
    )

    result = call_service

    assert result.success?
    assert_equal 1, result.repositories.size
  end

  test "handles generic error" do
    create_installation(
      account_login: "alice",
      error: RuntimeError.new("something went wrong")
    )

    result = call_service

    assert_not result.success?
    assert_includes result.error, "something went wrong"
  end

  test "formats repository data correctly" do
    installation = create_installation(
      account_login: "owner",
      repos: [
        { full_name: "owner/my-repo", private: true, description: "A test repo" }
      ]
    )

    result = call_service
    repo = result.repositories.first

    assert_equal "owner/my-repo", repo[:full_name]
    assert_equal "my-repo", repo[:name]
    assert_equal "owner", repo[:owner]
    assert_equal true, repo[:private]
    assert_equal "A test repo", repo[:description]
    assert_equal installation.github_installation_id, repo[:installation_id]
    assert_equal "owner", repo[:installation_account]
  end

  test "returns installations in result" do
    create_installation(account_login: "alice", repos: [])

    result = call_service

    assert result.success?
    assert_equal 1, result.installations.size
  end
end

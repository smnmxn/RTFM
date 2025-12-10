require "test_helper"
require "ostruct"

class GithubRepositoriesServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  class FakeOctokitClient
    def initialize(repos: [], error: nil)
      @repos = repos
      @error = error
    end

    def repos(_, **options)
      raise @error if @error
      @repos
    end
  end

  class TestableService < GithubRepositoriesService
    attr_accessor :fake_client

    def initialize(user, fake_client: nil)
      super(user)
      @fake_client = fake_client
    end

    private

    def build_client
      @fake_client
    end
  end

  # Override the service to use our testable version
  def service_with_fake_repos(repos)
    fake_repos = repos.map do |r|
      OpenStruct.new(
        id: r[:id] || rand(1000),
        full_name: r[:full_name],
        name: r[:full_name].split("/").last,
        owner: OpenStruct.new(login: r[:full_name].split("/").first),
        private: r[:private] || false,
        description: r[:description],
        pushed_at: Time.current,
        html_url: "https://github.com/#{r[:full_name]}",
        permissions: OpenStruct.new(admin: r[:admin].nil? ? true : r[:admin])
      )
    end

    service = GithubRepositoriesService.new(@user)
    service.instance_variable_set(:@client, FakeOctokitClient.new(repos: fake_repos))
    service
  end

  def service_with_error(error)
    service = GithubRepositoriesService.new(@user)
    service.instance_variable_set(:@client, FakeOctokitClient.new(error: error))
    service
  end

  test "returns repositories for user with admin access" do
    service = service_with_fake_repos([
      { full_name: "user/repo1", admin: true },
      { full_name: "user/repo2", admin: true }
    ])

    result = service.call

    assert result.success?
    assert_equal 2, result.repositories.size
    assert_equal "user/repo1", result.repositories.first[:full_name]
  end

  test "filters out repos without admin access" do
    service = service_with_fake_repos([
      { full_name: "user/repo1", admin: true },
      { full_name: "org/repo2", admin: false }
    ])

    result = service.call

    assert result.success?
    assert_equal 1, result.repositories.size
    assert_equal "user/repo1", result.repositories.first[:full_name]
  end

  test "handles unauthorized error" do
    service = service_with_error(Octokit::Unauthorized.new)

    result = service.call

    assert_not result.success?
    assert_includes result.error, "access denied"
  end

  test "handles forbidden error" do
    service = service_with_error(Octokit::Forbidden.new)

    result = service.call

    assert_not result.success?
    assert_includes result.error, "access denied"
  end

  test "handles generic API error" do
    service = service_with_error(Octokit::Error.new)

    result = service.call

    assert_not result.success?
    assert_includes result.error, "GitHub API error"
  end

  test "formats repository data correctly" do
    service = service_with_fake_repos([
      { full_name: "owner/my-repo", private: true, description: "A test repo" }
    ])

    result = service.call
    repo = result.repositories.first

    assert_equal "owner/my-repo", repo[:full_name]
    assert_equal "my-repo", repo[:name]
    assert_equal "owner", repo[:owner]
    assert_equal true, repo[:private]
    assert_equal "A test repo", repo[:description]
  end
end

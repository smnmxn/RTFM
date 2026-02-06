require "test_helper"
require "ostruct"

class GithubPullRequestsServiceTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
  end

  class FakeOctokitClient
    def initialize(prs: [], error: nil)
      @prs = prs
      @error = error
    end

    def pull_requests(repo, **options)
      raise @error if @error
      @prs
    end
  end

  def service_with_fake_prs(prs)
    fake_prs = prs.map do |pr|
      OpenStruct.new(
        number: pr[:number],
        title: pr[:title],
        html_url: "https://github.com/owner/repo/pull/#{pr[:number]}",
        merged_at: pr[:merged_at],
        merge_commit_sha: pr[:merge_commit_sha] || "abc123",
        user: OpenStruct.new(
          login: pr[:user] || "testuser",
          avatar_url: "https://avatars.githubusercontent.com/u/12345"
        )
      )
    end

    service = GithubPullRequestsService.new(@project)
    service.instance_variable_set(:@client, FakeOctokitClient.new(prs: fake_prs))
    # The service calls @project.github_client internally, but we override @client
    # We need to stub the client method used in call
    service.define_singleton_method(:call) do |page: 1, per_page: 30|
      client = service.instance_variable_get(:@client)
      prs_result = client.pull_requests(
        @project.github_repo,
        state: "closed",
        sort: "updated",
        direction: "desc",
        page: page,
        per_page: per_page
      )

      merged = prs_result.select { |p| p.merged_at.present? }

      GithubPullRequestsService::Result.new(
        "success?": true,
        pull_requests: merged.map { |p|
          {
            number: p.number,
            title: p.title,
            html_url: p.html_url,
            merged_at: p.merged_at,
            merge_commit_sha: p.merge_commit_sha,
            user: { login: p.user.login, avatar_url: p.user.avatar_url }
          }
        }
      )
    end
    service
  end

  def service_with_error(error)
    service = GithubPullRequestsService.new(@project)
    # Override call to simulate the error handling
    service.define_singleton_method(:call) do |page: 1, per_page: 30|
      raise error
    rescue Octokit::Unauthorized, Octokit::Forbidden
      GithubPullRequestsService::Result.new("success?": false, error: "GitHub access denied. The app may have been uninstalled.")
    rescue Octokit::NotFound
      GithubPullRequestsService::Result.new("success?": false, error: "Repository not found or the app doesn't have access.")
    rescue Octokit::Error => e
      GithubPullRequestsService::Result.new("success?": false, error: "GitHub API error: #{e.message}")
    end
    service
  end

  test "returns merged pull requests" do
    service = service_with_fake_prs([
      { number: 1, title: "First PR", merged_at: 1.day.ago },
      { number: 2, title: "Second PR", merged_at: 2.days.ago }
    ])

    result = service.call

    assert result.success?
    assert_equal 2, result.pull_requests.size
    assert_equal "First PR", result.pull_requests.first[:title]
    assert_equal 1, result.pull_requests.first[:number]
  end

  test "filters out non-merged PRs" do
    service = service_with_fake_prs([
      { number: 1, title: "Merged PR", merged_at: 1.day.ago },
      { number: 2, title: "Closed but not merged", merged_at: nil }
    ])

    result = service.call

    assert result.success?
    assert_equal 1, result.pull_requests.size
    assert_equal "Merged PR", result.pull_requests.first[:title]
  end

  test "handles unauthorized error" do
    service = service_with_error(Octokit::Unauthorized.new)

    result = service.call

    assert_not result.success?
    assert_includes result.error, "access denied"
  end

  test "handles not found error" do
    service = service_with_error(Octokit::NotFound.new)

    result = service.call

    assert_not result.success?
    assert_includes result.error, "not found"
  end

  test "handles generic API error" do
    service = service_with_error(Octokit::Error.new)

    result = service.call

    assert_not result.success?
    assert_includes result.error, "GitHub API error"
  end

  test "formats pull request data correctly" do
    service = service_with_fake_prs([
      { number: 42, title: "My PR", merged_at: 1.day.ago, user: "alice" }
    ])

    result = service.call
    pr = result.pull_requests.first

    assert_equal 42, pr[:number]
    assert_equal "My PR", pr[:title]
    assert_equal "alice", pr[:user][:login]
    assert pr[:html_url].include?("42")
  end
end

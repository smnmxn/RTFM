require "test_helper"

class AnalyzePullRequestJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:one)
    @user = users(:one)
  end

  class FakeOctokitClient
    def initialize(diff_response)
      @diff_response = diff_response
    end

    def pull_request(repo, number, **options)
      @diff_response
    end
  end

  class TestableJob < AnalyzePullRequestJob
    cattr_accessor :fake_client

    private

    def build_github_client(access_token)
      self.class.fake_client
    end
  end

  test "creates update record with placeholder content" do
    TestableJob.fake_client = FakeOctokitClient.new("+added line\n-removed line")

    assert_difference -> { @project.updates.count }, 1 do
      TestableJob.perform_now(
        project_id: @project.id,
        pull_request_number: 42,
        pull_request_url: "https://github.com/#{@project.github_repo}/pull/42",
        pull_request_title: "Add new feature",
        pull_request_body: "This adds something cool"
      )
    end

    update = @project.updates.last
    assert_equal "Add new feature", update.title
    assert_equal 42, update.pull_request_number
    assert_equal "draft", update.status
    assert_includes update.content, "This adds something cool"
  end

  test "does nothing if project not found" do
    assert_no_difference -> { Update.count } do
      AnalyzePullRequestJob.perform_now(
        project_id: 99999,
        pull_request_number: 1,
        pull_request_url: "https://github.com/test/repo/pull/1",
        pull_request_title: "Test",
        pull_request_body: ""
      )
    end
  end

  test "does nothing if user has no github_token" do
    @user.update!(github_token: nil)

    assert_no_difference -> { Update.count } do
      AnalyzePullRequestJob.perform_now(
        project_id: @project.id,
        pull_request_number: 1,
        pull_request_url: "https://github.com/test/repo/pull/1",
        pull_request_title: "Test",
        pull_request_body: ""
      )
    end
  end

  test "uses PR number as title when title is blank" do
    TestableJob.fake_client = FakeOctokitClient.new("")

    TestableJob.perform_now(
      project_id: @project.id,
      pull_request_number: 42,
      pull_request_url: "https://github.com/#{@project.github_repo}/pull/42",
      pull_request_title: "",
      pull_request_body: ""
    )

    update = @project.updates.last
    assert_equal "PR #42", update.title
  end
end

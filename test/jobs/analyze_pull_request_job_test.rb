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
    cattr_accessor :fake_analysis_result

    private

    def build_github_client(access_token)
      self.class.fake_client
    end

    def run_pr_analysis(project, update, diff, pr_title, pr_body)
      self.class.fake_analysis_result || { success: false, error: "Docker not available in test" }
    end
  end

  test "creates update record with AI-generated content on success" do
    TestableJob.fake_client = FakeOctokitClient.new("+added line\n-removed line")
    TestableJob.fake_analysis_result = {
      success: true,
      title: "New awesome feature",
      content: "This is AI-generated content describing the changes.",
      recommended_articles: {
        "articles" => [
          { "title" => "How to use the new feature", "description" => "A guide", "justification" => "New feature" }
        ],
        "no_articles_reason" => nil
      }
    }

    # Use PR number 999 to avoid fixture collision
    assert_difference -> { @project.updates.count }, 1 do
      assert_difference -> { Recommendation.count }, 1 do
        TestableJob.perform_now(
          project_id: @project.id,
          pull_request_number: 999,
          pull_request_url: "https://github.com/#{@project.github_repo}/pull/999",
          pull_request_title: "Add new feature",
          pull_request_body: "This adds something cool"
        )
      end
    end

    update = @project.updates.find_by(pull_request_number: 999)
    assert_equal "New awesome feature", update.title
    assert_equal "This is AI-generated content describing the changes.", update.content
    assert_equal 999, update.pull_request_number
    assert_equal "draft", update.status
    assert_equal "completed", update.analysis_status

    # Check Recommendation was created
    recommendation = update.recommendations.first
    assert_equal "How to use the new feature", recommendation.title
    assert_equal "A guide", recommendation.description
    assert_equal "pending", recommendation.status
  end

  test "falls back to placeholder content when AI analysis fails" do
    TestableJob.fake_client = FakeOctokitClient.new("+added line\n-removed line")
    TestableJob.fake_analysis_result = { success: false, error: "Docker timeout" }

    # Use PR number 998 to avoid fixture collision
    assert_difference -> { @project.updates.count }, 1 do
      TestableJob.perform_now(
        project_id: @project.id,
        pull_request_number: 998,
        pull_request_url: "https://github.com/#{@project.github_repo}/pull/998",
        pull_request_title: "Add new feature",
        pull_request_body: "This adds something cool"
      )
    end

    update = @project.updates.find_by(pull_request_number: 998)
    assert_equal "Add new feature", update.title
    assert_includes update.content, "This adds something cool"
    assert_includes update.content, "AI analysis was unavailable"
    assert_equal "failed", update.analysis_status
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

  test "uses PR number as title when title is blank and AI fails" do
    TestableJob.fake_client = FakeOctokitClient.new("")
    TestableJob.fake_analysis_result = { success: false, error: "No AI" }

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

  test "keeps original title when AI returns empty title" do
    TestableJob.fake_client = FakeOctokitClient.new("")
    TestableJob.fake_analysis_result = {
      success: true,
      title: "",
      content: "Some content",
      recommended_articles: { "articles" => [], "no_articles_reason" => "Internal change" }
    }

    TestableJob.perform_now(
      project_id: @project.id,
      pull_request_number: 42,
      pull_request_url: "https://github.com/#{@project.github_repo}/pull/42",
      pull_request_title: "Original PR Title",
      pull_request_body: ""
    )

    update = @project.updates.last
    assert_equal "Original PR Title", update.title
  end

  test "creates no recommendations when AI determines none needed" do
    TestableJob.fake_client = FakeOctokitClient.new("")
    TestableJob.fake_analysis_result = {
      success: true,
      title: "Refactor internals",
      content: "Some content",
      recommended_articles: { "articles" => [], "no_articles_reason" => "Internal refactoring with no user impact" }
    }

    assert_no_difference -> { Recommendation.count } do
      TestableJob.perform_now(
        project_id: @project.id,
        pull_request_number: 43,
        pull_request_url: "https://github.com/#{@project.github_repo}/pull/43",
        pull_request_title: "Original",
        pull_request_body: ""
      )
    end

    update = @project.updates.find_by(pull_request_number: 43)
    assert_equal "completed", update.analysis_status
    assert_empty update.recommendations
  end
end

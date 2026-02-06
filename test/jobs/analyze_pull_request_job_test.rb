require "test_helper"

class AnalyzePullRequestJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:one)
    @user = users(:one)
    # Create a project_repository so the job can find a client
    @project_repo = @project.project_repositories.find_or_create_by!(
      github_repo: @project.github_repo,
      github_installation_id: 12345
    )
  end

  class FakeOctokitClient
    def initialize(diff_response)
      @diff_response = diff_response
    end

    def pull_request(repo, number, **options)
      @diff_response
    end

    def compare(repo, base, head, **options)
      @diff_response
    end
  end

  class TestableJob < AnalyzePullRequestJob
    cattr_accessor :fake_client
    cattr_accessor :fake_analysis_result

    def perform(**kwargs)
      # Temporarily patch ProjectRepository#client to return our fake
      original_method = ProjectRepository.instance_method(:client)
      fake = self.class.fake_client
      ProjectRepository.define_method(:client) { fake }

      super
    ensure
      ProjectRepository.define_method(:client, original_method)
    end

    private

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

    recommendation = update.recommendations.first
    assert_equal "How to use the new feature", recommendation.title
    assert_equal "A guide", recommendation.description
    assert_equal "pending", recommendation.status
  end

  test "falls back to placeholder content when AI analysis fails" do
    TestableJob.fake_client = FakeOctokitClient.new("+added line\n-removed line")
    TestableJob.fake_analysis_result = { success: false, error: "Docker timeout" }

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

  test "does nothing if no client available" do
    project = projects(:two)

    assert_no_difference -> { Update.count } do
      AnalyzePullRequestJob.perform_now(
        project_id: project.id,
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
      pull_request_number: 997,
      pull_request_url: "https://github.com/#{@project.github_repo}/pull/997",
      pull_request_title: "",
      pull_request_body: ""
    )

    update = @project.updates.find_by(pull_request_number: 997)
    assert_equal "PR #997", update.title
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
      pull_request_number: 996,
      pull_request_url: "https://github.com/#{@project.github_repo}/pull/996",
      pull_request_title: "Original PR Title",
      pull_request_body: ""
    )

    update = @project.updates.find_by(pull_request_number: 996)
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
        pull_request_number: 995,
        pull_request_url: "https://github.com/#{@project.github_repo}/pull/995",
        pull_request_title: "Original",
        pull_request_body: ""
      )
    end

    update = @project.updates.find_by(pull_request_number: 995)
    assert_equal "completed", update.analysis_status
    assert_empty update.recommendations
  end
end

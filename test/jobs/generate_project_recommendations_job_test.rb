require "test_helper"

class GenerateProjectRecommendationsJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:one)
    @project.update!(
      analysis_status: "completed",
      project_overview: "A project management tool",
      analysis_summary: "Rails app with user auth and task management"
    )
  end

  class TestableJob < GenerateProjectRecommendationsJob
    cattr_accessor :fake_generation_result

    private

    def run_recommendations_generation(project)
      self.class.fake_generation_result || { success: false, error: "Docker not available in test" }
    end
  end

  test "creates recommendations on success" do
    TestableJob.fake_generation_result = {
      success: true,
      recommendations: [
        { "title" => "How to create a project", "description" => "Guide to creating projects", "justification" => "Core feature" },
        { "title" => "How to invite team members", "description" => "Guide to inviting users", "justification" => "Collaboration feature" }
      ]
    }

    assert_difference -> { Recommendation.count }, 2 do
      TestableJob.perform_now(project_id: @project.id)
    end

    recommendations = @project.recommendations.where(source_update_id: nil).order(created_at: :asc)
    assert_equal "How to create a project", recommendations.first.title
    assert_nil recommendations.first.source_update_id
    assert_equal "pending", recommendations.first.status
  end

  test "does nothing when generation fails" do
    TestableJob.fake_generation_result = { success: false, error: "Docker timeout" }

    assert_no_difference -> { Recommendation.count } do
      TestableJob.perform_now(project_id: @project.id)
    end
  end

  test "does nothing if project not found" do
    assert_no_difference -> { Recommendation.count } do
      GenerateProjectRecommendationsJob.perform_now(project_id: 99999)
    end
  end

  test "handles empty recommendations array" do
    TestableJob.fake_generation_result = {
      success: true,
      recommendations: []
    }

    assert_no_difference -> { Recommendation.count } do
      TestableJob.perform_now(project_id: @project.id)
    end
  end

  test "builds context with existing changelogs and recommendations" do
    # Create an existing changelog
    @project.updates.create!(
      title: "Added dark mode",
      content: "Users can now toggle dark mode",
      pull_request_number: 1,
      pull_request_url: "https://github.com/test/repo/pull/1",
      status: :published
    )

    # Create an existing recommendation
    @project.recommendations.create!(
      title: "How to enable dark mode",
      description: "Guide",
      justification: "New feature",
      status: :pending
    )

    job = GenerateProjectRecommendationsJob.new
    context_json = job.send(:build_context_json, @project)
    context = JSON.parse(context_json)

    assert_equal @project.name, context["project_name"]
    assert_equal @project.project_overview, context["project_overview"]
    assert_includes context["existing_recommendation_titles"], "How to enable dark mode"
    changelog_titles = context["existing_changelogs"].map { |c| c["title"] }
    assert_includes changelog_titles, "Added dark mode"
  end
end

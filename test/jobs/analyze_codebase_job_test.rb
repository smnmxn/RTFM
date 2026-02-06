require "test_helper"
require "ostruct"

class AnalyzeCodebaseJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:one)
    @user = users(:one)
    # Create a project_repository so the job passes the guard clause
    @project_repo = @project.project_repositories.find_or_create_by!(
      github_repo: @project.github_repo,
      github_installation_id: 12345
    )
  end

  test "does nothing if project not found" do
    assert_nothing_raised do
      AnalyzeCodebaseJob.perform_now(99999)
    end
  end

  test "does nothing if no installation or repositories" do
    project = projects(:two)

    AnalyzeCodebaseJob.perform_now(project.id)

    project.reload
    assert_nil project.analysis_status
  end

  test "sets status to running during analysis" do
    @project.update!(analysis_status: "pending")
    status_during_analysis = nil

    job = AnalyzeCodebaseJob.new
    job.define_singleton_method(:run_analysis) do |project|
      status_during_analysis = project.reload.analysis_status
      { success: true, summary: "Test", metadata: {}, commit_sha: "abc123" }
    end

    job.perform(@project.id)

    assert_equal "running", status_during_analysis
  end

  test "updates project with results on success" do
    summary = "# Test Project\n\nA test summary"
    metadata = { "tech_stack" => ["ruby", "rails"] }
    commit_sha = "abc123def456"

    job = AnalyzeCodebaseJob.new
    job.define_singleton_method(:run_analysis) do |project|
      {
        success: true,
        summary: summary,
        metadata: metadata,
        commit_sha: commit_sha
      }
    end

    job.perform(@project.id)

    @project.reload
    assert_equal "completed", @project.analysis_status
    assert_equal summary, @project.analysis_summary
    assert_equal metadata, @project.analysis_metadata
    assert_equal commit_sha, @project.analysis_commit_sha
    assert_not_nil @project.analyzed_at
  end

  test "sets status to failed on unsuccessful analysis" do
    job = AnalyzeCodebaseJob.new
    job.define_singleton_method(:run_analysis) do |project|
      { success: false, error: "Docker failed" }
    end

    job.perform(@project.id)

    @project.reload
    assert_equal "failed", @project.analysis_status
  end

  test "sets status to failed and re-raises on exception" do
    job = AnalyzeCodebaseJob.new
    job.define_singleton_method(:run_analysis) do |project|
      raise StandardError, "Something went wrong"
    end

    assert_raises(StandardError) do
      job.perform(@project.id)
    end

    @project.reload
    assert_equal "failed", @project.analysis_status
  end
end

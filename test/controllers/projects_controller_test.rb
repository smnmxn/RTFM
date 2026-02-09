require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    use_app_subdomain
  end

  # Authentication tests
  test "new requires authentication" do
    get new_project_path
    assert_response :redirect
  end

  test "new redirects to onboarding" do
    sign_in_as(@user)
    get new_project_path
    assert_redirected_to new_onboarding_project_path
  end

  test "repositories requires authentication" do
    get repositories_projects_path
    assert_response :redirect
  end

  test "create requires authentication" do
    post projects_path, params: { github_repo: "owner/repo" }
    assert_response :redirect
  end

  test "create redirects to onboarding" do
    sign_in_as(@user)
    post projects_path, params: { github_repo: "owner/repo" }
    assert_redirected_to new_onboarding_project_path
  end

  test "show requires authentication" do
    project = projects(:one)
    get project_path(project)
    assert_response :redirect
  end

  test "show renders project page" do
    sign_in_as(@user)
    project = projects(:one)
    get project_path(project)
    assert_response :success
  end

  test "show cannot view other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)
    get project_path(other_project)
    assert_redirected_to projects_path
  end

  test "destroy requires authentication" do
    project = projects(:one)
    delete project_path(project)
    assert_response :redirect
  end

  test "destroy removes project and redirects" do
    sign_in_as(@user)
    project = projects(:one_second)

    assert_difference -> { Project.count }, -1 do
      delete project_path(project)
    end

    assert_redirected_to projects_path
  end

  test "destroy cannot delete other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)

    assert_no_difference -> { Project.count } do
      delete project_path(other_project)
    end

    assert_redirected_to projects_path
  end

  test "pull_requests requires authentication" do
    project = projects(:one)
    get pull_requests_project_path(project)
    assert_response :redirect
  end

  test "pull_requests cannot access other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)
    get pull_requests_project_path(other_project)
    assert_redirected_to projects_path
  end

  # Analyze action tests
  test "analyze requires authentication" do
    project = projects(:one)
    post analyze_project_path(project)
    assert_response :redirect
  end

  test "analyze sets status to pending and redirects" do
    sign_in_as(@user)
    project = projects(:one)

    post analyze_project_path(project)

    assert_redirected_to project_path(project)
    assert_match(/analysis started/i, flash[:notice])

    project.reload
    assert_equal "pending", project.analysis_status
  end

  test "analyze does not proceed if already running" do
    sign_in_as(@user)
    project = projects(:one)
    project.update!(analysis_status: "running")

    post analyze_project_path(project)

    assert_redirected_to project_path(project)
    assert_match(/already in progress/i, flash[:alert])
  end

  test "analyze cannot trigger for other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)

    post analyze_project_path(other_project)

    assert_redirected_to projects_path
  end

  # Analyze pull request tests
  test "analyze_pull_request requires authentication" do
    project = projects(:one)
    post analyze_pull_request_project_path(project, pr_number: 123)
    assert_response :redirect
  end

  test "analyze_pull_request redirects with success notice" do
    sign_in_as(@user)
    project = projects(:one)

    post analyze_pull_request_project_path(project, pr_number: 123),
         params: { pr_title: "Test PR", pr_url: "https://github.com/test/repo/pull/123" }

    assert_response :redirect
    assert_match(/Analysis started for PR #123/i, flash[:notice])
  end

  test "analyze_pull_request does not proceed if already running" do
    sign_in_as(@user)
    project = projects(:one)
    project.updates.create!(
      title: "Existing",
      pull_request_number: 123,
      pull_request_url: "https://github.com/test/repo/pull/123",
      analysis_status: "running"
    )

    post analyze_pull_request_project_path(project, pr_number: 123)

    assert_response :redirect
    assert_match(/already in progress/i, flash[:alert])
  end

  test "analyze_pull_request cannot trigger for other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)

    post analyze_pull_request_project_path(other_project, pr_number: 123)

    assert_redirected_to projects_path
  end

  test "analyze_pull_request uses default values when params missing" do
    sign_in_as(@user)
    project = projects(:one)

    post analyze_pull_request_project_path(project, pr_number: 456)

    assert_response :redirect
    assert_match(/Analysis started for PR #456/i, flash[:notice])
  end

  # ========================================
  # Inbox turbo stream UI update tests
  # ========================================

  test "approve_article turbo stream updates inbox and articles badges" do
    sign_in_as(@user)
    project = projects(:one)
    article = articles(:inbox_article_completed)

    post approve_article_project_path(project),
         params: { article_id: article.id, section_id: sections(:getting_started).id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="inbox-tab-badge"'
    assert_includes response.body, 'target="articles-tab-badge"'
    assert_includes response.body, 'target="inbox-progress"'
    assert_includes response.body, 'target="articles-section"'
    assert_includes response.body, 'target="articles-folder-tree"'
  end

  test "reject_article turbo stream updates inbox and articles badges" do
    sign_in_as(@user)
    project = projects(:one)
    article = articles(:inbox_article_completed)

    post reject_article_project_path(project),
         params: { article_id: article.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="inbox-tab-badge"'
    assert_includes response.body, 'target="articles-tab-badge"'
    assert_includes response.body, 'target="inbox-progress"'
    assert_includes response.body, 'target="articles-folder-tree"'
  end

  test "undo_reject_article turbo stream updates inbox and articles badges" do
    sign_in_as(@user)
    project = projects(:one)
    article = articles(:inbox_article_completed)
    article.update!(review_status: :rejected, reviewed_at: Time.current)

    post undo_reject_article_project_path(project),
         params: { article_id: article.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="inbox-tab-badge"'
    assert_includes response.body, 'target="articles-tab-badge"'
    assert_includes response.body, 'target="inbox-progress"'
    assert_includes response.body, 'target="articles-folder-tree"'
  end

  test "accept_recommendation turbo stream updates inbox badge" do
    sign_in_as(@user)
    project = projects(:one)
    recommendation = recommendations(:inbox_recommendation_webhooks)

    post accept_recommendation_project_path(project),
         params: { recommendation_id: recommendation.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="inbox-tab-badge"'
    assert_includes response.body, 'target="inbox-progress"'
    assert_includes response.body, 'target="recommendations-section"'
  end

  test "reject_recommendation turbo stream updates inbox badge" do
    sign_in_as(@user)
    project = projects(:one)
    recommendation = recommendations(:inbox_recommendation_webhooks)

    post reject_recommendation_project_path(project),
         params: { recommendation_id: recommendation.id },
         headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="inbox-tab-badge"'
    assert_includes response.body, 'target="inbox-progress"'
    assert_includes response.body, 'target="recommendations-section"'
  end

  test "inbox_articles turbo stream updates inbox badge" do
    sign_in_as(@user)
    project = projects(:one)

    get inbox_articles_project_path(project),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, 'target="inbox-tab-badge"'
    assert_includes response.body, 'target="inbox-progress"'
    assert_includes response.body, 'target="articles-section"'
  end

  test "show renders inbox and articles tab badge partials" do
    sign_in_as(@user)
    project = projects(:one)

    get project_path(project)

    assert_response :success
    assert_includes response.body, 'id="inbox-tab-badge"'
    assert_includes response.body, 'id="articles-tab-badge"'
  end
end

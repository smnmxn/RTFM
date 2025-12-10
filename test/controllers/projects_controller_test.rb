require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "new requires authentication" do
    get new_project_path
    assert_redirected_to login_path
  end

  test "new renders repository selection page" do
    sign_in_as(@user)
    get new_project_path
    assert_response :success
    assert_select "h2", "Connect a GitHub Repository"
  end

  test "repositories requires authentication" do
    get repositories_projects_path
    assert_redirected_to login_path
  end

  test "create requires authentication" do
    post projects_path, params: { github_repo: "owner/repo" }
    assert_redirected_to login_path
  end

  test "destroy requires authentication" do
    project = projects(:one)
    delete project_path(project)
    assert_redirected_to login_path
  end

  test "destroy removes project" do
    sign_in_as(@user)
    project = projects(:one)

    assert_difference -> { Project.count }, -1 do
      delete project_path(project)
    end

    assert_redirected_to dashboard_path
  end

  test "destroy cannot delete other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)

    assert_no_difference -> { Project.count } do
      delete project_path(other_project)
    end

    assert_response :not_found
  end

  test "create validates github_repo presence" do
    sign_in_as(@user)

    post projects_path, params: { github_repo: "" }

    assert_redirected_to new_project_path
    assert_match(/can't be blank/i, flash[:alert])
  end

  test "create validates github_repo format" do
    sign_in_as(@user)

    post projects_path, params: { github_repo: "invalid-format" }

    assert_redirected_to new_project_path
    assert_match(/owner\/repo/i, flash[:alert])
  end

  test "create prevents duplicate github_repo for same user" do
    sign_in_as(@user)
    existing_project = projects(:one)

    post projects_path, params: { github_repo: existing_project.github_repo }

    assert_redirected_to new_project_path
    assert_match(/already connected/i, flash[:alert])
  end

  test "show requires authentication" do
    project = projects(:one)
    get project_path(project)
    assert_redirected_to login_path
  end

  test "show renders project page" do
    sign_in_as(@user)
    project = projects(:one)

    get project_path(project)

    assert_response :success
    assert_select "h2", project.name
  end

  test "show cannot view other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)

    get project_path(other_project)

    assert_response :not_found
  end

  test "pull_requests requires authentication" do
    project = projects(:one)
    get pull_requests_project_path(project)
    assert_redirected_to login_path
  end

  test "pull_requests cannot access other user's project" do
    sign_in_as(@user)
    other_project = projects(:two)

    get pull_requests_project_path(other_project)

    assert_response :not_found
  end

  # Analyze action tests
  test "analyze requires authentication" do
    project = projects(:one)
    post analyze_project_path(project)
    assert_redirected_to login_path
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

    assert_response :not_found
  end
end

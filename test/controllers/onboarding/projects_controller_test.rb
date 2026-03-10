require "test_helper"

class Onboarding::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    use_app_subdomain
  end

  test "free user at project limit is redirected to billing on new" do
    sign_in_as(@user)
    # User :one already has completed projects (onboarding_step: nil)
    # Free plan allows 1 project
    completed = @user.projects.where(onboarding_step: nil).count
    assert completed >= 1, "Expected user to have at least 1 completed project"

    get new_onboarding_project_path
    assert_redirected_to billing_path
    assert_match(/plan limit/, flash[:alert])
  end

  test "free user at project limit is redirected to billing on create" do
    sign_in_as(@user)

    assert_no_difference -> { Project.count } do
      post onboarding_projects_path
    end

    assert_redirected_to billing_path
    assert_match(/plan limit/, flash[:alert])
  end

  test "free user with no completed projects can create" do
    # Use user :two who has 1 completed project by default
    # We need a user with 0 completed projects
    user = users(:two)
    user.projects.where(onboarding_step: nil).destroy_all
    sign_in_as(user)

    assert_difference -> { Project.count }, 1 do
      post onboarding_projects_path
    end

    assert_response :redirect
    assert_not_equal billing_path, response.location.sub(%r{https?://[^/]+}, "")
  end

  test "pro user can create projects beyond free limit" do
    @user.update!(plan: "pro")
    sign_in_as(@user)

    assert_difference -> { Project.count }, 1 do
      post onboarding_projects_path
    end

    assert_response :redirect
    assert_not_equal billing_path, response.location.sub(%r{https?://[^/]+}, "")
  end
end

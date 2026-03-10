require "test_helper"

class BillingEnforcementTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @project = projects(:one)
    use_app_subdomain
  end

  # ========================================
  # Custom domain gate
  # ========================================

  test "free user cannot update custom domain via HTML" do
    sign_in_as(@user)
    assert @user.free?

    patch update_custom_domain_project_path(@project),
          params: { project: { custom_domain: "help.example.com" } }

    assert_redirected_to billing_path
    assert_match(/Pro plan/, flash[:alert])
  end

  test "free user cannot update custom domain via Turbo Stream" do
    sign_in_as(@user)
    assert @user.free?

    patch update_custom_domain_project_path(@project),
          params: { project: { custom_domain: "help.example.com" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.body, "Upgrade to Pro"
  end

  test "pro user can update custom domain" do
    @user.update!(plan: "pro")
    sign_in_as(@user)

    patch update_custom_domain_project_path(@project),
          params: { project: { custom_domain: "help.example.com" } }

    # Should not redirect to billing (may redirect elsewhere or succeed)
    refute_equal billing_path, response.location&.sub(%r{https?://[^/]+}, "")
  end
end

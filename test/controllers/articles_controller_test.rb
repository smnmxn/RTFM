require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @failed_article = articles(:failed_article)
    @draft_article = articles(:draft_article)
    use_app_subdomain
  end

  # Show action tests
  test "show requires authentication" do
    get project_article_path(@draft_article.project, @draft_article)
    assert_response :redirect
  end

  test "show redirects to project page with article selected" do
    sign_in_as(@user)

    get project_article_path(@draft_article.project, @draft_article)

    assert_response :redirect
    assert_redirected_to project_path(@draft_article.project, article: @draft_article.id)
  end

  test "show cannot view other user's article" do
    sign_in_as(@user)
    other_project = projects(:two)
    other_recommendation = Recommendation.create!(
      project: other_project,
      title: "Other recommendation",
      description: "Test",
      justification: "Test",
      status: :generated
    )
    other_article = Article.create!(
      project: other_project,
      recommendation: other_recommendation,
      title: "Other article",
      content: "Content",
      generation_status: :generation_completed
    )

    get project_article_path(other_project, other_article)

    assert_response :not_found
  end

  # Regenerate action tests
  test "regenerate requires authentication" do
    post regenerate_project_article_path(@failed_article.project, @failed_article)
    assert_response :redirect
  end

  test "regenerate updates status and redirects for failed article" do
    sign_in_as(@user)

    post regenerate_project_article_path(@failed_article.project, @failed_article)

    assert_redirected_to project_path(@failed_article.project, article: @failed_article.id)
    @failed_article.reload
    assert @failed_article.generation_running?
    assert_equal "Regenerating article...", @failed_article.content
  end

  test "regenerate allows regeneration of completed article" do
    sign_in_as(@user)

    post regenerate_project_article_path(@draft_article.project, @draft_article)

    assert_redirected_to project_path(@draft_article.project, article: @draft_article.id)
    @draft_article.reload
    assert @draft_article.generation_running?
    assert_equal "Regenerating article...", @draft_article.content
  end

  test "regenerate does not allow regeneration while generation is running" do
    sign_in_as(@user)
    @draft_article.update!(generation_status: :generation_running)

    post regenerate_project_article_path(@draft_article.project, @draft_article)

    assert_redirected_to project_path(@draft_article.project)
    assert_match(/cannot be regenerated while generation is in progress/i, flash[:alert])
  end

  test "regenerate cannot access other user's article" do
    sign_in_as(@user)
    other_project = projects(:two)
    other_recommendation = Recommendation.create!(
      project: other_project,
      title: "Other recommendation",
      description: "Test",
      justification: "Test",
      status: :generated
    )
    other_article = Article.create!(
      project: other_project,
      recommendation: other_recommendation,
      title: "Other article",
      content: "Failed",
      generation_status: :generation_failed
    )

    post regenerate_project_article_path(other_project, other_article)

    assert_response :not_found
  end

  test "regenerate responds with json" do
    sign_in_as(@user)

    post regenerate_project_article_path(@failed_article.project, @failed_article),
         headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
         params: {}.to_json

    assert_response :success
    json = JSON.parse(response.body)
    assert json["redirect_url"].present?
    @failed_article.reload
    assert @failed_article.generation_running?
  end

  # update_field action tests
  test "update_field requires authentication" do
    patch update_field_project_article_path(@draft_article.project, @draft_article),
          params: { field: "introduction", value: "New intro" },
          as: :json

    assert_response :redirect
  end

  test "update_field updates introduction" do
    sign_in_as(@user)

    patch update_field_project_article_path(@draft_article.project, @draft_article),
          params: { field: "introduction", value: "Updated introduction text" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" },
          as: :json

    assert_response :success
    @draft_article.reload
    assert_equal "Updated introduction text", @draft_article.introduction
  end

  test "update_field updates nested step title" do
    sign_in_as(@user)

    patch update_field_project_article_path(@draft_article.project, @draft_article),
          params: { field: "steps.0.title", value: "Updated Step Title" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" },
          as: :json

    assert_response :success
    @draft_article.reload
    assert_equal "Updated Step Title", @draft_article.steps[0]["title"]
  end

  test "update_field updates prerequisite" do
    sign_in_as(@user)

    patch update_field_project_article_path(@draft_article.project, @draft_article),
          params: { field: "prerequisites.0", value: "Updated prerequisite" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" },
          as: :json

    assert_response :success
    @draft_article.reload
    assert_equal "Updated prerequisite", @draft_article.prerequisites[0]
  end

  # add_array_item action tests
  test "add_array_item requires authentication" do
    post add_array_item_project_article_path(@draft_article.project, @draft_article),
         params: { field: "tips" },
         as: :json

    assert_response :redirect
  end

  test "add_array_item adds a new tip" do
    sign_in_as(@user)
    original_count = @draft_article.tips.count

    post add_array_item_project_article_path(@draft_article.project, @draft_article),
         params: { field: "tips" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" },
         as: :json

    assert_response :success
    @draft_article.reload
    assert_equal original_count + 1, @draft_article.tips.count
    assert_equal "New item", @draft_article.tips.last
  end

  test "add_array_item adds a new step with title and content" do
    sign_in_as(@user)
    original_count = @draft_article.steps.count

    post add_array_item_project_article_path(@draft_article.project, @draft_article),
         params: { field: "steps" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" },
         as: :json

    assert_response :success
    @draft_article.reload
    assert_equal original_count + 1, @draft_article.steps.count
    assert_equal "New Step", @draft_article.steps.last["title"]
    assert_equal "Step content here...", @draft_article.steps.last["content"]
  end

  test "add_array_item adds a new prerequisite" do
    sign_in_as(@user)
    original_count = @draft_article.prerequisites.count

    post add_array_item_project_article_path(@draft_article.project, @draft_article),
         params: { field: "prerequisites" },
         headers: { "Accept" => "text/vnd.turbo-stream.html" },
         as: :json

    assert_response :success
    @draft_article.reload
    assert_equal original_count + 1, @draft_article.prerequisites.count
  end

  # remove_array_item action tests
  test "remove_array_item requires authentication" do
    delete remove_array_item_project_article_path(@draft_article.project, @draft_article),
           params: { field: "tips", index: 0 },
           as: :json

    assert_response :redirect
  end

  test "remove_array_item removes a tip" do
    sign_in_as(@user)
    original_count = @draft_article.tips.count
    first_tip = @draft_article.tips.first

    delete remove_array_item_project_article_path(@draft_article.project, @draft_article),
           params: { field: "tips", index: 0 },
           headers: { "Accept" => "text/vnd.turbo-stream.html" },
           as: :json

    assert_response :success
    @draft_article.reload
    assert_equal original_count - 1, @draft_article.tips.count
    assert_not_includes @draft_article.tips, first_tip
  end

  test "remove_array_item removes a step" do
    sign_in_as(@user)
    original_count = @draft_article.steps.count

    delete remove_array_item_project_article_path(@draft_article.project, @draft_article),
           params: { field: "steps", index: 0 },
           headers: { "Accept" => "text/vnd.turbo-stream.html" },
           as: :json

    assert_response :success
    @draft_article.reload
    assert_equal original_count - 1, @draft_article.steps.count
  end

  test "remove_array_item removes a prerequisite" do
    sign_in_as(@user)
    original_count = @draft_article.prerequisites.count

    delete remove_array_item_project_article_path(@draft_article.project, @draft_article),
           params: { field: "prerequisites", index: 0 },
           headers: { "Accept" => "text/vnd.turbo-stream.html" },
           as: :json

    assert_response :success
    @draft_article.reload
    assert_equal original_count - 1, @draft_article.prerequisites.count
  end
end

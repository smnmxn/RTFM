require "test_helper"

class RecommendationTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @pending = recommendations(:pending_recommendation)
    @rejected = recommendations(:rejected_recommendation)
    @generated = recommendations(:generated_recommendation)
  end

  # --- Validations ---

  test "valid recommendation" do
    recommendation = Recommendation.new(
      project: @project,
      title: "New Recommendation"
    )
    assert recommendation.valid?
  end

  test "requires title" do
    recommendation = Recommendation.new(project: @project, title: nil)
    assert_not recommendation.valid?
    assert_includes recommendation.errors[:title], "can't be blank"
  end

  # --- Enums ---

  test "status enum" do
    assert @pending.pending?
    assert @rejected.rejected?
    assert @generated.generated?
  end

  # --- reject! / generate! ---

  test "reject! sets status to rejected and rejected_at" do
    freeze_time do
      @pending.reject!
      assert @pending.rejected?
      assert_equal Time.current, @pending.rejected_at
    end
  end

  test "generate! sets status to generated" do
    rec = recommendations(:inbox_recommendation_webhooks)
    rec.generate!
    assert rec.generated?
  end

  # --- Scopes ---

  test "pending scope returns only pending recommendations" do
    results = @project.recommendations.pending
    assert results.all?(&:pending?)
    assert_includes results, @pending
  end

  test "rejected scope returns only rejected recommendations" do
    results = @project.recommendations.rejected
    assert results.all?(&:rejected?)
    assert_includes results, @rejected
  end

  test "generated scope returns only generated recommendations" do
    results = @project.recommendations.generated
    assert results.all?(&:generated?)
    assert_includes results, @generated
  end

  # --- Associations ---

  test "belongs to project" do
    assert_equal @project, @pending.project
  end

  test "has one article" do
    assert_respond_to @generated, :article
    assert_equal articles(:published_article), @generated.article
  end
end

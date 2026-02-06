require "test_helper"

class StepImageTest < ActiveSupport::TestCase
  setup do
    @article = articles(:draft_article)
  end

  # --- Validations ---

  test "requires step_index" do
    si = StepImage.new(article: @article, step_index: nil)
    assert_not si.valid?
    assert_includes si.errors[:step_index], "can't be blank"
  end

  test "step_index must be unique within article" do
    # Create a step_image with an attached image using a unique index
    si1 = @article.step_images.new(step_index: 99)
    si1.image.attach(io: StringIO.new("fake"), filename: "test.png", content_type: "image/png")
    si1.save!

    si2 = StepImage.new(article: @article, step_index: 99)
    assert_not si2.valid?
    assert_includes si2.errors[:step_index], "has already been taken"
  end

  test "requires image" do
    si = StepImage.new(article: @article, step_index: 5)
    assert_not si.valid?
    assert_includes si.errors[:image], "can't be blank"
  end

  # --- Render status helpers ---

  test "render_successful? returns true when status is success" do
    si = StepImage.new(render_status: "success")
    assert si.render_successful?
  end

  test "render_successful? returns false for other statuses" do
    si = StepImage.new(render_status: "pending")
    assert_not si.render_successful?

    si.render_status = "warning"
    assert_not si.render_successful?

    si.render_status = "failed"
    assert_not si.render_successful?
  end

  test "render_has_warnings? returns true when status is warning" do
    si = StepImage.new(render_status: "warning")
    assert si.render_has_warnings?
  end

  test "render_has_warnings? returns false for other statuses" do
    si = StepImage.new(render_status: "success")
    assert_not si.render_has_warnings?
  end

  # --- Quality / metadata accessors ---

  test "quality_score reads from render_metadata" do
    si = StepImage.new(render_metadata: { "qualityScore" => { "score" => 85, "rating" => "good" } })
    assert_equal 85, si.quality_score
  end

  test "quality_score returns nil when no metadata" do
    si = StepImage.new(render_metadata: nil)
    assert_nil si.quality_score
  end

  test "quality_rating reads from render_metadata" do
    si = StepImage.new(render_metadata: { "qualityScore" => { "score" => 85, "rating" => "good" } })
    assert_equal "good", si.quality_rating
  end

  test "quality_rating returns nil when no metadata" do
    si = StepImage.new(render_metadata: nil)
    assert_nil si.quality_rating
  end

  test "page_errors returns array from render_metadata" do
    si = StepImage.new(render_metadata: { "pageErrors" => ["Error 1", "Error 2"] })
    assert_equal ["Error 1", "Error 2"], si.page_errors
  end

  test "page_errors returns empty array when nil" do
    si = StepImage.new(render_metadata: nil)
    assert_equal [], si.page_errors
  end

  test "failed_resources returns array from render_metadata" do
    si = StepImage.new(render_metadata: { "failedResources" => ["res1.js"] })
    assert_equal ["res1.js"], si.failed_resources
  end

  test "failed_resources returns empty array when nil" do
    si = StepImage.new(render_metadata: nil)
    assert_equal [], si.failed_resources
  end

  # --- Scopes ---

  test "with_warnings scope returns step_images with warning render_status" do
    si = @article.step_images.new(step_index: 10, render_status: "warning")
    si.image.attach(io: StringIO.new("fake"), filename: "warn.png", content_type: "image/png")
    si.save!

    results = @article.step_images.with_warnings
    assert results.all? { |s| s.render_status == "warning" }
    assert_includes results, si
  end

  test "failed scope returns step_images with failed render_status" do
    si = @article.step_images.new(step_index: 11, render_status: "failed")
    si.image.attach(io: StringIO.new("fake"), filename: "fail.png", content_type: "image/png")
    si.save!

    results = @article.step_images.failed
    assert results.all? { |s| s.render_status == "failed" }
    assert_includes results, si
  end
end

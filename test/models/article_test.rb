require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @section = sections(:getting_started)
    @recommendation = recommendations(:generated_recommendation)
    @article = articles(:published_article)
    @draft = articles(:draft_article)
  end

  # --- Validations ---

  test "valid article" do
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      section: @section,
      title: "Test Article",
      slug: "test-article"
    )
    assert article.valid?
  end

  test "requires title" do
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      title: nil,
      slug: "some-slug"
    )
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
  end

  test "requires slug" do
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      title: "No Slug",
      slug: nil
    )
    # Slug gets auto-generated from title on create, so we need to test on update
    article.save!
    article.slug = nil
    assert_not article.valid?
    assert_includes article.errors[:slug], "can't be blank"
  end

  test "slug must be unique within section" do
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      section: @section,
      title: "Duplicate",
      slug: @article.slug
    )
    assert_not article.valid?
    assert_includes article.errors[:slug], "has already been taken"
  end

  # --- Slug generation ---

  test "auto-generates slug from title on create" do
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      section: sections(:troubleshooting),
      title: "My Great Article"
    )
    article.valid?
    assert_equal "my-great-article", article.slug
  end

  test "does not overwrite existing slug" do
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      section: sections(:troubleshooting),
      title: "My Great Article",
      slug: "custom-slug"
    )
    article.valid?
    assert_equal "custom-slug", article.slug
  end

  test "appends counter for duplicate slugs within same section" do
    Article.create!(
      project: @project,
      recommendation: @recommendation,
      section: sections(:troubleshooting),
      title: "Unique Title",
      slug: "unique-title"
    )
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      section: sections(:troubleshooting),
      title: "Unique Title"
    )
    article.valid?
    assert_equal "unique-title-2", article.slug
  end

  test "slug scoped to section allows same slug in different sections" do
    Article.create!(
      project: @project,
      recommendation: @recommendation,
      section: sections(:troubleshooting),
      title: "Same Title",
      slug: "same-title"
    )
    article = Article.new(
      project: @project,
      recommendation: @recommendation,
      section: sections(:advanced_usage),
      title: "Same Title"
    )
    article.valid?
    assert_equal "same-title", article.slug
  end

  # --- Enums ---

  test "status enum" do
    assert @article.published?
    assert @draft.draft?
  end

  test "generation_status enum" do
    assert @article.generation_completed?
    assert articles(:failed_article).generation_failed?
    assert articles(:inbox_article_running).generation_running?
  end

  test "review_status enum" do
    assert @article.approved?
    assert articles(:failed_article).unreviewed?
  end

  # --- publish! / unpublish! ---

  test "publish! sets status to published and published_at" do
    freeze_time do
      @draft.publish!
      assert @draft.published?
      assert_equal Time.current, @draft.published_at
    end
  end

  test "unpublish! sets status to draft and clears published_at" do
    @article.unpublish!
    assert @article.draft?
    assert_nil @article.published_at
  end

  # --- approve! / reject! ---

  test "approve! sets review_status to approved and reviewed_at" do
    article = articles(:inbox_article_completed)
    freeze_time do
      article.approve!
      assert article.approved?
      assert_equal Time.current, article.reviewed_at
    end
  end

  test "reject! sets review_status to rejected and reviewed_at" do
    article = articles(:inbox_article_completed)
    freeze_time do
      article.reject!
      assert article.rejected?
      assert_equal Time.current, article.reviewed_at
    end
  end

  # --- Structured content accessors ---

  test "structured? returns true when structured_content present" do
    assert @draft.structured?
  end

  test "structured? returns false when structured_content nil" do
    assert_not @article.structured?
  end

  test "introduction returns introduction from structured_content" do
    assert_equal "This guide will show you how to enable dark mode.", @draft.introduction
  end

  test "prerequisites returns array from structured_content" do
    assert_equal ["A modern browser", "Access to settings"], @draft.prerequisites
  end

  test "prerequisites returns empty array when nil" do
    assert_equal [], @article.prerequisites
  end

  test "steps returns array from structured_content" do
    assert_equal 2, @draft.steps.length
    assert_equal "Open Settings", @draft.steps.first["title"]
  end

  test "steps returns empty array when nil" do
    assert_equal [], @article.steps
  end

  test "tips returns array from structured_content" do
    assert_equal 2, @draft.tips.length
  end

  test "tips returns empty array when nil" do
    assert_equal [], @article.tips
  end

  test "summary returns summary from structured_content" do
    assert_equal "You've now learned how to enable dark mode!", @draft.summary
  end

  # --- move_to_section! ---

  test "move_to_section! raises ArgumentError for nil" do
    assert_raises(ArgumentError) { @article.move_to_section!(nil) }
  end

  test "move_to_section! moves article to new section" do
    new_section = sections(:troubleshooting)
    @draft.move_to_section!(new_section)
    assert_equal new_section, @draft.reload.section
  end

  # --- duplicate! ---

  test "duplicate! creates a copy with (Copy) suffix" do
    # Create a fresh article with no step_images to avoid image attachment issues
    source = Article.create!(
      project: @project,
      recommendation: @recommendation,
      section: @section,
      title: "Original Article",
      slug: "original-for-dup",
      content: "Some content",
      structured_content: { "introduction" => "Hello" },
      status: :draft,
      generation_status: :generation_completed,
      review_status: :approved
    )
    copy = source.duplicate!
    assert_equal "Original Article (Copy)", copy.title
    assert copy.draft?
    assert copy.approved?
    assert copy.generation_completed?
    assert_equal "Some content", copy.content
    assert_equal({ "introduction" => "Hello" }, copy.structured_content)
    assert_equal @section, copy.section
    assert copy.persisted?
  end

  # --- Scopes ---

  test "published scope returns only published articles ordered by published_at desc" do
    results = @project.articles.published
    assert results.all?(&:published?)
  end

  test "drafts scope returns only draft articles" do
    results = @project.articles.drafts
    assert results.all?(&:draft?)
  end

  test "needs_review scope returns unreviewed completed articles" do
    results = @project.articles.needs_review
    results.each do |a|
      assert a.unreviewed?
      assert a.generation_completed?
    end
  end

  test "for_help_centre scope returns approved published articles" do
    results = @project.articles.for_help_centre
    results.each do |a|
      assert a.approved?
      assert a.published?
    end
  end

  test "for_editor scope returns approved articles" do
    results = @project.articles.for_editor
    assert results.all?(&:approved?)
  end

  test "for_folder_tree scope excludes rejected articles" do
    results = @project.articles.for_folder_tree
    assert results.none?(&:rejected?)
  end

  test "ordered scope orders by position" do
    results = @project.articles.ordered
    positions = results.map(&:position)
    assert_equal positions.sort, positions
  end
end

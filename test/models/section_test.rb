require "test_helper"

class SectionTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @section = sections(:getting_started)
  end

  # --- Validations ---

  test "valid section" do
    section = Section.new(
      project: @project,
      name: "New Section",
      slug: "new-section",
      position: 10
    )
    assert section.valid?
  end

  test "requires name" do
    section = Section.new(project: @project, name: nil, slug: "test", position: 0)
    assert_not section.valid?
    assert_includes section.errors[:name], "can't be blank"
  end

  test "requires slug" do
    # Name must also be blank to prevent auto-generation from name
    section = Section.new(project: @project, name: nil, slug: nil, position: 0)
    assert_not section.valid?
    assert_includes section.errors[:slug], "can't be blank"
  end

  test "slug must be unique within project" do
    section = Section.new(
      project: @project,
      name: "Duplicate",
      slug: @section.slug,
      position: 10
    )
    assert_not section.valid?
    assert_includes section.errors[:slug], "has already been taken"
  end

  test "requires position" do
    section = Section.new(project: @project, name: "Test", slug: "test-pos", position: nil)
    assert_not section.valid?
    assert_includes section.errors[:position], "can't be blank"
  end

  # --- Slug generation ---

  test "auto-generates slug from name on create" do
    section = Section.new(project: @project, name: "My New Section", position: 10)
    section.valid?
    assert_equal "my-new-section", section.slug
  end

  test "does not overwrite existing slug" do
    section = Section.new(project: @project, name: "My Section", slug: "custom-slug", position: 10)
    section.valid?
    assert_equal "custom-slug", section.slug
  end

  # --- Enums ---

  test "section_type enum" do
    assert @section.template?
  end

  test "status enum" do
    assert @section.accepted?
  end

  # --- Scopes ---

  test "visible scope returns accepted and visible sections" do
    results = @project.sections.visible
    results.each do |s|
      assert s.accepted?
      assert s.visible?
    end
  end

  test "ordered scope orders by position asc" do
    results = @project.sections.ordered
    positions = results.map(&:position)
    assert_equal positions.sort, positions
  end

  test "with_published_articles scope returns sections having published articles" do
    results = @project.sections.with_published_articles
    results.each do |s|
      assert s.articles.where(status: :published).exists?
    end
  end

  # --- Class methods ---

  test "create_templates_for creates 4 template sections" do
    project = projects(:two)
    assert_difference "project.sections.count", 4 do
      Section.create_templates_for(project)
    end
    slugs = project.sections.pluck(:slug)
    assert_includes slugs, "getting-started"
    assert_includes slugs, "daily-tasks"
    assert_includes slugs, "advanced-usage"
    assert_includes slugs, "troubleshooting"
  end

  test "create_templates_for is idempotent" do
    project = projects(:two)
    Section.create_templates_for(project)
    assert_no_difference "project.sections.count" do
      Section.create_templates_for(project)
    end
  end

  # --- Instance methods ---

  test "icon_name returns icon when set" do
    assert_equal "paper-airplane", @section.icon_name
  end

  test "icon_name falls back to default when icon is nil" do
    section = Section.new(icon: nil)
    assert_equal Section::DEFAULT_ICON, section.icon_name
  end

  test "published_articles returns only published articles" do
    results = @section.published_articles
    assert results.all?(&:published?)
  end

  test "pending_recommendations returns only pending recommendations" do
    results = @section.pending_recommendations
    assert results.all?(&:pending?)
  end
end

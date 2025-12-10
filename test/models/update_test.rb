require "test_helper"

class UpdateTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
  end

  test "valid update" do
    update = Update.new(project: @project, title: "New Feature")
    assert update.valid?
  end

  test "requires title" do
    update = Update.new(project: @project, title: nil)
    assert_not update.valid?
    assert_includes update.errors[:title], "can't be blank"
  end

  test "defaults to draft status" do
    update = Update.new(project: @project, title: "Test")
    assert_equal "draft", update.status
    assert update.draft?
  end

  test "status enum works" do
    update = Update.new(project: @project, title: "Test")

    update.status = :draft
    assert update.draft?
    assert_not update.published?

    update.status = :published
    assert update.published?
    assert_not update.draft?
  end

  test "publish! sets status and published_at" do
    update = Update.create!(project: @project, title: "Test")
    assert update.draft?
    assert_nil update.published_at

    freeze_time do
      update.publish!
      assert update.published?
      assert_equal Time.current, update.published_at
    end
  end

  test "published scope returns published updates ordered by published_at desc" do
    published = updates(:published_update)
    draft = updates(:draft_update)

    results = Update.published
    assert_includes results, published
    assert_not_includes results, draft
  end

  test "drafts scope returns draft updates ordered by created_at desc" do
    published = updates(:published_update)
    draft = updates(:draft_update)

    results = Update.drafts
    assert_includes results, draft
    assert_not_includes results, published
  end

  test "belongs to project" do
    update = updates(:draft_update)
    assert_equal projects(:one), update.project
  end
end

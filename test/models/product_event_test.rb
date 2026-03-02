require "test_helper"

class ProductEventTest < ActiveSupport::TestCase
  test "valid event" do
    event = ProductEvent.new(
      user: users(:one),
      event_name: "article.published",
      project: projects(:one)
    )
    assert event.valid?
  end

  test "requires user" do
    event = ProductEvent.new(event_name: "article.published")
    assert_not event.valid?
    assert_includes event.errors[:user], "must exist"
  end

  test "requires event_name" do
    event = ProductEvent.new(user: users(:one))
    assert_not event.valid?
    assert_includes event.errors[:event_name], "can't be blank"
  end

  test "auto-sets category from event_name" do
    event = ProductEvent.new(
      user: users(:one),
      event_name: "article.published"
    )
    event.valid?
    assert_equal "article", event.category
  end

  test "auto-sets category for dotted event names" do
    event = ProductEvent.new(
      user: users(:one),
      event_name: "settings.custom_domain_added"
    )
    event.valid?
    assert_equal "settings", event.category
  end

  test "project is optional" do
    event = ProductEvent.new(
      user: users(:one),
      event_name: "project.created"
    )
    assert event.valid?
  end

  test "properties stores JSON" do
    event = ProductEvent.create!(
      user: users(:one),
      event_name: "article.edited",
      project: projects(:one),
      properties: { "article_id" => 42, "field" => "title" }
    )
    event.reload
    assert_equal 42, event.properties["article_id"]
    assert_equal "title", event.properties["field"]
  end

  test "since scope" do
    old = ProductEvent.create!(user: users(:one), event_name: "article.published", created_at: 10.days.ago)
    recent = ProductEvent.create!(user: users(:one), event_name: "article.published", created_at: 1.day.ago)

    results = ProductEvent.since(5.days.ago)
    assert_includes results, recent
    assert_not_includes results, old
  end

  test "between scope" do
    old = ProductEvent.create!(user: users(:one), event_name: "article.published", created_at: 10.days.ago)
    recent = ProductEvent.create!(user: users(:one), event_name: "article.published", created_at: 1.day.ago)

    results = ProductEvent.between(5.days.ago, Time.current)
    assert_includes results, recent
    assert_not_includes results, old
  end

  test "for_event scope" do
    pub = ProductEvent.create!(user: users(:one), event_name: "article.published")
    edit = ProductEvent.create!(user: users(:one), event_name: "article.edited")

    results = ProductEvent.for_event("article.published")
    assert_includes results, pub
    assert_not_includes results, edit
  end

  test "for_category scope" do
    article = ProductEvent.create!(user: users(:one), event_name: "article.published")
    settings = ProductEvent.create!(user: users(:one), event_name: "settings.branding_updated")

    results = ProductEvent.for_category("article")
    assert_includes results, article
    assert_not_includes results, settings
  end

  test "for_project scope" do
    with_project = ProductEvent.create!(user: users(:one), event_name: "article.published", project: projects(:one))
    other_project = ProductEvent.create!(user: users(:one), event_name: "article.published", project: projects(:two))

    results = ProductEvent.for_project(projects(:one).id)
    assert_includes results, with_project
    assert_not_includes results, other_project
  end

  test "for_user scope" do
    user1_event = ProductEvent.create!(user: users(:one), event_name: "article.published")
    user2_event = ProductEvent.create!(user: users(:two), event_name: "article.published")

    results = ProductEvent.for_user(users(:one).id)
    assert_includes results, user1_event
    assert_not_includes results, user2_event
  end
end

require "test_helper"

class RecordProductEventJobTest < ActiveSupport::TestCase
  test "creates product event" do
    assert_difference "ProductEvent.count", 1 do
      RecordProductEventJob.perform_now(
        user_id: users(:one).id,
        event_name: "article.published"
      )
    end
  end

  test "creates event with project" do
    RecordProductEventJob.perform_now(
      user_id: users(:one).id,
      event_name: "article.published",
      project_id: projects(:one).id
    )
    event = ProductEvent.last
    assert_equal projects(:one).id, event.project_id
  end

  test "creates event with properties" do
    RecordProductEventJob.perform_now(
      user_id: users(:one).id,
      event_name: "article.edited",
      properties: { "article_id" => 42, "field" => "title" }
    )
    event = ProductEvent.last
    assert_equal 42, event.properties["article_id"]
    assert_equal "title", event.properties["field"]
  end

  test "auto-sets category" do
    RecordProductEventJob.perform_now(
      user_id: users(:one).id,
      event_name: "settings.custom_domain_added"
    )
    event = ProductEvent.last
    assert_equal "settings", event.category
  end

  test "handles nil properties" do
    RecordProductEventJob.perform_now(
      user_id: users(:one).id,
      event_name: "project.created",
      properties: nil
    )
    event = ProductEvent.last
    assert_nil event.properties
  end

  test "discards on error" do
    assert_nothing_raised do
      RecordProductEventJob.perform_now(
        user_id: -1,
        event_name: "article.published"
      )
    end
  end
end

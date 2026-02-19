require "test_helper"

class AnalyticsEventTest < ActiveSupport::TestCase
  test "valid event" do
    event = AnalyticsEvent.new(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/"
    )
    assert event.valid?
  end

  test "requires visitor_id" do
    event = AnalyticsEvent.new(event_type: "page_view", page_path: "/")
    assert_not event.valid?
    assert_includes event.errors[:visitor_id], "can't be blank"
  end

  test "requires event_type" do
    event = AnalyticsEvent.new(visitor_id: SecureRandom.uuid, page_path: "/")
    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
  end

  test "requires page_path" do
    event = AnalyticsEvent.new(visitor_id: SecureRandom.uuid, event_type: "page_view")
    assert_not event.valid?
    assert_includes event.errors[:page_path], "can't be blank"
  end

  test "validates event_type inclusion" do
    event = AnalyticsEvent.new(
      visitor_id: SecureRandom.uuid,
      event_type: "invalid_type",
      page_path: "/"
    )
    assert_not event.valid?
    assert_includes event.errors[:event_type], "is not included in the list"
  end

  test "all EVENT_TYPES are valid" do
    AnalyticsEvent::EVENT_TYPES.each do |type|
      event = AnalyticsEvent.new(
        visitor_id: SecureRandom.uuid,
        event_type: type,
        page_path: "/"
      )
      assert event.valid?, "Expected #{type} to be valid"
    end
  end

  test "page_views scope returns only page_view events" do
    results = AnalyticsEvent.page_views
    assert results.all? { |e| e.event_type == "page_view" }
    assert results.count > 0
  end

  test "engagement scope excludes page_view events" do
    results = AnalyticsEvent.engagement
    assert results.none? { |e| e.event_type == "page_view" }
    assert results.count > 0
  end

  test "since scope filters by date" do
    results = AnalyticsEvent.since(3.days.ago)
    assert results.count > 0
    assert results.all? { |e| e.created_at >= 3.days.ago }
    # old_page_view is 60 days ago, should be excluded
    assert_not results.include?(analytics_events(:old_page_view))
  end

  test "between scope filters by date range" do
    results = AnalyticsEvent.between(3.days.ago, Time.current)
    assert results.count > 0
    old_event = analytics_events(:old_page_view)
    assert_not results.include?(old_event)
  end

  test "event_data stores JSON" do
    event = AnalyticsEvent.create!(
      visitor_id: SecureRandom.uuid,
      event_type: "video_progress",
      page_path: "/",
      event_data: { "progress" => 50, "duration" => 90 }
    )
    event.reload
    assert_equal 50, event.event_data["progress"]
    assert_equal 90, event.event_data["duration"]
  end
end

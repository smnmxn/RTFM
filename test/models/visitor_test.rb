require "test_helper"

class VisitorTest < ActiveSupport::TestCase
  def setup
    @visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: Time.current,
      total_page_views: 1,
      total_events: 1
    )
  end

  test "valid visitor" do
    assert @visitor.valid?
  end

  test "requires visitor_id" do
    visitor = Visitor.new(first_seen_at: Time.current, last_seen_at: Time.current)
    assert_not visitor.valid?
    assert_includes visitor.errors[:visitor_id], "can't be blank"
  end

  test "requires first_seen_at" do
    visitor = Visitor.new(visitor_id: SecureRandom.uuid, last_seen_at: Time.current)
    assert_not visitor.valid?
    assert_includes visitor.errors[:first_seen_at], "can't be blank"
  end

  test "requires last_seen_at" do
    visitor = Visitor.new(visitor_id: SecureRandom.uuid, first_seen_at: Time.current)
    assert_not visitor.valid?
    assert_includes visitor.errors[:last_seen_at], "can't be blank"
  end

  test "visitor_id must be unique" do
    duplicate = Visitor.new(
      visitor_id: @visitor.visitor_id,
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:visitor_id], "has already been taken"
  end

  test "has_many analytics_events" do
    assert_respond_to @visitor, :analytics_events
  end

  test "returning_visitor? returns false for first visit" do
    visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      total_page_views: 1
    )
    assert_not visitor.returning_visitor?
  end

  test "returning_visitor? returns true for multiple visits" do
    visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: Time.current,
      total_page_views: 5
    )
    assert visitor.returning_visitor?
  end

  test "identified? returns false when email is nil" do
    assert_not @visitor.identified?
  end

  test "identified? returns true when email is present" do
    @visitor.update!(email: "test@example.com")
    assert @visitor.identified?
  end

  test "converted? returns false when user_id is nil" do
    assert_not @visitor.converted?
  end

  test "converted? returns true when user_id is present" do
    @visitor.update!(user_id: 1)
    assert @visitor.converted?
  end

  test "identify! sets email and name" do
    @visitor.identify!(email: "test@example.com", name: "Test User")
    assert_equal "test@example.com", @visitor.email
    assert_equal "Test User", @visitor.name
    assert_not_nil @visitor.identified_at
  end

  test "identify! sets user_id when provided" do
    @visitor.identify!(email: "test@example.com", user_id: 123)
    assert_equal 123, @visitor.user_id
  end

  test "identify! does not overwrite if already identified with same email" do
    original_time = 1.day.ago
    @visitor.update!(email: "test@example.com", identified_at: original_time)
    @visitor.identify!(email: "test@example.com")
    assert_equal original_time.to_i, @visitor.identified_at.to_i
  end

  test "record_activity! increments total_events" do
    assert_difference "@visitor.reload.total_events", 1 do
      @visitor.record_activity!(event_type: "cta_click")
    end
  end

  test "record_activity! increments total_page_views for page_view events" do
    assert_difference "@visitor.reload.total_page_views", 1 do
      @visitor.record_activity!(event_type: "page_view")
    end
  end

  test "record_activity! does not increment total_page_views for non-page_view events" do
    assert_no_difference "@visitor.reload.total_page_views" do
      @visitor.record_activity!(event_type: "video_play")
    end
  end

  test "record_activity! updates last_seen_at" do
    old_time = @visitor.last_seen_at
    sleep 0.01 # Small delay to ensure time difference
    @visitor.record_activity!(event_type: "page_view")
    assert @visitor.reload.last_seen_at > old_time
  end

  test "record_activity! updates metadata when provided" do
    @visitor.record_activity!(
      event_type: "page_view",
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0",
      device_type: "mobile",
      browser_family: "Chrome",
      os_family: "iOS"
    )
    @visitor.reload
    assert_equal "192.168.1.1", @visitor.last_ip_address
    assert_equal "Mozilla/5.0", @visitor.last_user_agent
    assert_equal "mobile", @visitor.device_type
    assert_equal "Chrome", @visitor.browser_family
    assert_equal "iOS", @visitor.os_family
  end

  test "returning scope returns visitors with more than 1 page view" do
    returning = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: Time.current,
      total_page_views: 5
    )
    assert_includes Visitor.returning, returning
    assert_not_includes Visitor.returning, @visitor
  end

  test "new_visitors scope returns visitors with 1 page view" do
    assert_includes Visitor.new_visitors, @visitor
  end

  test "identified scope returns visitors with email" do
    identified = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      email: "test@example.com"
    )
    assert_includes Visitor.identified, identified
    assert_not_includes Visitor.identified, @visitor
  end

  test "anonymous scope returns visitors without email" do
    assert_includes Visitor.anonymous, @visitor
  end

  test "from_source scope returns visitors from specific UTM source" do
    from_linkedin = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: Time.current,
      last_seen_at: Time.current,
      utm_source: "linkedin"
    )
    assert_includes Visitor.from_source("linkedin"), from_linkedin
    assert_not_includes Visitor.from_source("linkedin"), @visitor
  end

  test "active_since scope returns visitors active since date" do
    recent = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.hour.ago,
      last_seen_at: 1.hour.ago
    )
    old = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 2.days.ago,
      last_seen_at: 2.days.ago
    )
    assert_includes Visitor.active_since(1.day.ago), recent
    assert_not_includes Visitor.active_since(1.day.ago), old
  end
end

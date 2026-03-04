require "test_helper"

class VisitorTrackingIntegrationTest < ActionDispatch::IntegrationTest
  # Test the job directly since async jobs aren't being triggered in integration tests
  test "RecordAnalyticsEventJob creates visitor with UTM attribution" do
    visitor_id = SecureRandom.uuid

    assert_difference "Visitor.count", 1 do
      RecordAnalyticsEventJob.perform_now(
        visitor_id: visitor_id,
        event_type: "page_view",
        page_path: "/",
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        utm_source: "linkedin",
        utm_medium: "social",
        utm_campaign: "launch",
        referrer_url: "https://linkedin.com"
      )
    end

    visitor = Visitor.find_by(visitor_id: visitor_id)
    assert_equal "linkedin", visitor.utm_source
    assert_equal "social", visitor.utm_medium
    assert_equal "launch", visitor.utm_campaign
    assert_equal "/", visitor.initial_landing_page
    assert_equal "linkedin.com", visitor.initial_referrer_host
    assert_equal 1, visitor.total_page_views
    assert_equal 1, visitor.total_events
    assert_not_nil visitor.first_seen_at
    assert_not_nil visitor.last_seen_at
  end

  test "RecordAnalyticsEventJob updates existing visitor activity" do
    visitor_id = SecureRandom.uuid

    # First event
    RecordAnalyticsEventJob.perform_now(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: "/"
    )

    visitor = Visitor.find_by(visitor_id: visitor_id)
    initial_page_views = visitor.total_page_views
    initial_events = visitor.total_events
    initial_last_seen = visitor.last_seen_at

    # Second event
    sleep 0.01
    RecordAnalyticsEventJob.perform_now(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: "/blog"
    )

    visitor.reload
    assert_equal initial_page_views + 1, visitor.total_page_views
    assert_equal initial_events + 1, visitor.total_events
    assert visitor.last_seen_at > initial_last_seen
  end

  test "visitor identification via identify! method" do
    visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: Time.current,
      last_seen_at: Time.current
    )

    assert_not visitor.identified?

    visitor.identify!(email: "test@example.com", name: "Test User")

    assert visitor.identified?
    assert_equal "test@example.com", visitor.email
    assert_equal "Test User", visitor.name
    assert_not_nil visitor.identified_at
  end

  test "visitor does not create duplicate on subsequent events" do
    visitor_id = SecureRandom.uuid

    RecordAnalyticsEventJob.perform_now(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: "/"
    )

    initial_count = Visitor.count

    RecordAnalyticsEventJob.perform_now(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: "/blog"
    )

    assert_equal initial_count, Visitor.count
  end

  test "visitor records capture device and browser info" do
    visitor_id = SecureRandom.uuid

    RecordAnalyticsEventJob.perform_now(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
    )

    visitor = Visitor.find_by(visitor_id: visitor_id)
    assert_equal "mobile", visitor.device_type
    assert_equal "Safari", visitor.browser_family
    assert_equal "iOS", visitor.os_family
  end

  test "analytics service includes visitor breakdown" do
    # Create some test visitors
    returning_visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 2.days.ago,
      last_seen_at: 1.day.ago,
      total_page_views: 5,
      total_events: 8,
      utm_source: "twitter"
    )

    identified_visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: 1.day.ago,
      total_page_views: 1,
      total_events: 1,
      email: "identified@example.com",
      identified_at: 1.day.ago
    )

    # Create corresponding analytics events
    2.times do
      AnalyticsEvent.create!(
        visitor_id: returning_visitor.visitor_id,
        event_type: "page_view",
        page_path: "/test"
      )
    end

    AnalyticsEvent.create!(
      visitor_id: identified_visitor.visitor_id,
      event_type: "page_view",
      page_path: "/test"
    )

    service = AnalyticsSummaryService.new(2.days.ago, Time.current)
    data = service.call

    assert data[:visitor_breakdown].present?
    assert_equal 2, data[:visitor_breakdown][:total_visitors]
    assert_equal 1, data[:visitor_breakdown][:returning_visitors]
    assert_equal 1, data[:visitor_breakdown][:identified_visitors]
  end

  test "utm_breakdown shows first-touch attribution from visitors" do
    # Create visitors with different UTM sources
    linkedin_visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: 1.day.ago,
      total_page_views: 3,
      utm_source: "linkedin"
    )

    twitter_visitor = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: 1.day.ago,
      total_page_views: 2,
      utm_source: "twitter"
    )

    # Create events
    [ linkedin_visitor, twitter_visitor ].each do |visitor|
      AnalyticsEvent.create!(
        visitor_id: visitor.visitor_id,
        event_type: "page_view",
        page_path: "/test"
      )
    end

    service = AnalyticsSummaryService.new(2.days.ago, Time.current)
    data = service.call

    utm_sources = data[:utm_breakdown].map { |u| u[:source] }
    assert_includes utm_sources, "linkedin"
    assert_includes utm_sources, "twitter"

    # Verify counts are visitor counts, not event counts
    linkedin_entry = data[:utm_breakdown].find { |u| u[:source] == "linkedin" }
    assert_equal 1, linkedin_entry[:visitors]
  end
end

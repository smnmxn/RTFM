require "test_helper"

class RecordAnalyticsEventJobTest < ActiveSupport::TestCase
  test "creates analytics event" do
    assert_difference "AnalyticsEvent.count", 1 do
      RecordAnalyticsEventJob.perform_now(
        visitor_id: SecureRandom.uuid,
        event_type: "page_view",
        page_path: "/",
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      )
    end
  end

  test "parses Chrome on macOS desktop" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )
    event = AnalyticsEvent.last
    assert_equal "desktop", event.device_type
    assert_equal "Chrome", event.browser_family
    assert_equal "macOS", event.os_family
  end

  test "parses Safari on iPhone" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    )
    event = AnalyticsEvent.last
    assert_equal "mobile", event.device_type
    assert_equal "Safari", event.browser_family
    assert_equal "iOS", event.os_family
  end

  test "parses Firefox on Windows" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0"
    )
    event = AnalyticsEvent.last
    assert_equal "desktop", event.device_type
    assert_equal "Firefox", event.browser_family
    assert_equal "Windows", event.os_family
  end

  test "parses Edge browser" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
    )
    event = AnalyticsEvent.last
    assert_equal "Edge", event.browser_family
  end

  test "parses Android tablet" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0 (Linux; Android 13; SM-X200) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )
    event = AnalyticsEvent.last
    assert_equal "tablet", event.device_type
    assert_equal "Android", event.os_family
  end

  test "extracts referrer host" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      referrer_url: "https://www.google.com/search?q=supportpages",
      user_agent: "Mozilla/5.0"
    )
    event = AnalyticsEvent.last
    assert_equal "www.google.com", event.referrer_host
  end

  test "handles nil referrer" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: "Mozilla/5.0"
    )
    event = AnalyticsEvent.last
    assert_nil event.referrer_host
  end

  test "stores UTM params" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      utm_source: "twitter",
      utm_medium: "social",
      utm_campaign: "launch",
      user_agent: "Mozilla/5.0"
    )
    event = AnalyticsEvent.last
    assert_equal "twitter", event.utm_source
    assert_equal "social", event.utm_medium
    assert_equal "launch", event.utm_campaign
  end

  test "stores event_data" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "video_progress",
      page_path: "/",
      event_data: { "progress" => 50, "duration" => 90 },
      user_agent: "Mozilla/5.0"
    )
    event = AnalyticsEvent.last
    assert_equal 50, event.event_data["progress"]
  end

  test "discards on error" do
    # The job has discard_on StandardError, so invalid data should not raise
    assert_nothing_raised do
      RecordAnalyticsEventJob.perform_now(
        visitor_id: "",
        event_type: "page_view",
        page_path: "/"
      )
    end
  end

  test "handles blank user agent" do
    RecordAnalyticsEventJob.perform_now(
      visitor_id: SecureRandom.uuid,
      event_type: "page_view",
      page_path: "/",
      user_agent: nil
    )
    event = AnalyticsEvent.last
    assert_equal "unknown", event.device_type
    assert_equal "Other", event.browser_family
    assert_equal "Other", event.os_family
  end
end

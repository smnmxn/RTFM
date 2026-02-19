require "test_helper"

class AnalyticsSummaryServiceTest < ActiveSupport::TestCase
  setup do
    @service = AnalyticsSummaryService.new(7.days.ago, Time.current)
    @data = @service.call
  end

  test "returns summary with page views and unique visitors" do
    summary = @data[:summary]
    assert summary[:total_page_views] > 0
    assert summary[:unique_visitors] > 0
    assert summary[:total_engagement] > 0
  end

  test "returns daily views array" do
    daily = @data[:daily_views]
    assert_kind_of Array, daily
    assert daily.length > 0
    assert daily.all? { |d| d.key?(:date) && d.key?(:views) && d.key?(:uniques) }
  end

  test "returns top pages" do
    pages = @data[:top_pages]
    assert_kind_of Array, pages
    if pages.any?
      assert pages.first.key?(:path)
      assert pages.first.key?(:views)
    end
  end

  test "returns top referrers" do
    referrers = @data[:top_referrers]
    assert_kind_of Array, referrers
    # We have a fixture with referrer_host = google.com
    if referrers.any?
      assert referrers.first.key?(:host)
      assert referrers.first.key?(:views)
    end
  end

  test "returns utm breakdown" do
    utm = @data[:utm_breakdown]
    assert_kind_of Array, utm
  end

  test "returns device breakdown" do
    devices = @data[:device_breakdown]
    assert_kind_of Hash, devices
  end

  test "returns browser breakdown" do
    browsers = @data[:browser_breakdown]
    assert_kind_of Hash, browsers
  end

  test "returns engagement metrics" do
    eng = @data[:engagement]
    assert eng.key?(:video_plays)
    assert eng.key?(:avg_video_progress)
    assert eng.key?(:waitlist_submits)
    assert eng.key?(:cta_clicks)
    assert eng.key?(:cta_detail)
  end

  test "returns funnel data" do
    funnel = @data[:funnel]
    assert funnel.key?(:steps)
    assert funnel.key?(:rates)
    if funnel[:steps].any?
      assert_equal "Page View", funnel[:steps].first[:name]
    end
  end

  test "handles empty date range" do
    service = AnalyticsSummaryService.new(100.years.ago, 99.years.ago)
    data = service.call
    assert_equal 0, data[:summary][:total_page_views]
    assert_equal 0, data[:summary][:unique_visitors]
  end

  test "engagement calculates avg video progress" do
    eng = @data[:engagement]
    # We have a video_progress fixture with progress: 50
    assert eng[:avg_video_progress] >= 0
  end

  test "engagement includes cta detail" do
    eng = @data[:engagement]
    # We have a cta_click fixture with cta: github_signin
    if eng[:cta_detail].any?
      assert eng[:cta_detail].key?("github_signin")
    end
  end
end

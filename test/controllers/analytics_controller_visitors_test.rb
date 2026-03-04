require "test_helper"

class AnalyticsControllerVisitorsTest < ActionDispatch::IntegrationTest
  setup do
    use_app_subdomain

    @admin = User.create!(
      email: "admin@test.com",
      github_uid: "123456",
      github_username: "admin",
      admin: true
    )
    sign_in_as(@admin)

    # Create test visitors
    @visitor1 = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 2.days.ago,
      last_seen_at: 1.day.ago,
      total_page_views: 5,
      total_events: 7,
      utm_source: "linkedin",
      device_type: "desktop",
      browser_family: "Chrome",
      os_family: "macOS"
    )

    @visitor2 = Visitor.create!(
      visitor_id: SecureRandom.uuid,
      first_seen_at: 1.day.ago,
      last_seen_at: 1.hour.ago,
      total_page_views: 1,
      total_events: 1,
      email: "test@example.com",
      name: "Test User",
      identified_at: 1.hour.ago,
      device_type: "mobile",
      browser_family: "Safari",
      os_family: "iOS"
    )

    # Create some analytics events
    AnalyticsEvent.create!(
      visitor_id: @visitor1.visitor_id,
      event_type: "page_view",
      page_path: "/"
    )
    AnalyticsEvent.create!(
      visitor_id: @visitor1.visitor_id,
      event_type: "video_play",
      page_path: "/",
      event_data: { video_id: "intro" }
    )
  end

  test "visitors tab shows list of visitors" do
    get analytics_path(tab: "visitors")
    assert_response :success

    # Check for visitor data
    assert_select "td", text: /#{@visitor1.visitor_id[0..7]}/
    assert_select "td", text: /#{@visitor2.email}/

    # Check for status badges
    assert_select "span", text: "Returning"
    assert_select "span", text: "New"
  end

  test "visitors tab shows visitor statistics" do
    get analytics_path(tab: "visitors")
    assert_response :success

    # Check for statistics
    assert_select "td", text: @visitor1.total_page_views.to_s
    assert_select "td", text: @visitor2.total_events.to_s
  end

  test "visitors tab shows attribution data" do
    get analytics_path(tab: "visitors")
    assert_response :success

    # Check for UTM source
    assert_select "td", text: /linkedin/
  end

  test "visitor detail page shows comprehensive information" do
    get analytics_visitor_path(@visitor1)
    assert_response :success

    # Check for summary cards
    assert_select "p", text: "Page Views"
    assert_select "p", text: @visitor1.total_page_views.to_s

    # Check for visitor ID
    assert_select "p", text: @visitor1.visitor_id

    # Check for technical details
    assert_select "p", text: /#{@visitor1.device_type}/i
    assert_select "p", text: @visitor1.browser_family
    assert_select "p", text: @visitor1.os_family
  end

  test "visitor detail page shows events" do
    get analytics_visitor_path(@visitor1)
    assert_response :success

    # Check for event summary
    assert_select "h2", text: "Event Summary"

    # Check for recent activity
    assert_select "h2", text: /Recent Activity/
    assert_select "span", text: "Page view"
    assert_select "span", text: "Video play"
  end

  test "identified visitor shows email and name" do
    get analytics_visitor_path(@visitor2)
    assert_response :success

    assert_select "p", text: @visitor2.email
    assert_select "p", text: @visitor2.name
    # Check for identified status in the page content
    assert_match /Identified/i, response.body
  end

  test "anonymous visitor shows anonymous status" do
    get analytics_visitor_path(@visitor1)
    assert_response :success

    assert_select "p", text: "Anonymous Visitor"
  end

  test "visitor with utm data shows attribution" do
    get analytics_visitor_path(@visitor1)
    assert_response :success

    assert_select "h2", text: /Attribution/
    assert_select "p", text: @visitor1.utm_source
  end

  test "requires admin access for visitors tab" do
    # Sign out admin
    delete logout_path

    # Try to access visitors tab
    get analytics_path(tab: "visitors")
    # Redirects to bare domain login
    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  test "requires admin access for visitor detail" do
    # Sign out admin
    delete logout_path

    # Try to access visitor detail
    get analytics_visitor_path(@visitor1)
    # Redirects to bare domain login
    assert_response :redirect
    assert_match %r{/login}, response.location
  end

  private

  def sign_in_as(user)
    post test_login_path(user.id)
  end
end

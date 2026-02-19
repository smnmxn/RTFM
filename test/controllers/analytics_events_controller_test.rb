require "test_helper"

class AnalyticsEventsControllerTest < ActionDispatch::IntegrationTest
  test "returns 204 for valid event" do
    cookies[:_sp_vid] = "550e8400-e29b-41d4-a716-446655440000"

    assert_enqueued_with(job: RecordAnalyticsEventJob) do
      post analytics_track_path,
        params: { event_type: "cta_click", page_path: "/", event_data: { cta: "github_signin" } },
        as: :json
    end

    assert_response :no_content
  end

  test "returns 204 without enqueuing when no visitor cookie" do
    assert_no_enqueued_jobs(only: RecordAnalyticsEventJob) do
      post analytics_track_path,
        params: { event_type: "cta_click", page_path: "/" },
        as: :json
    end

    assert_response :no_content
  end

  test "returns 204 without enqueuing for invalid event type" do
    cookies[:_sp_vid] = "550e8400-e29b-41d4-a716-446655440000"

    assert_no_enqueued_jobs(only: RecordAnalyticsEventJob) do
      post analytics_track_path,
        params: { event_type: "hacking_attempt", page_path: "/" },
        as: :json
    end

    assert_response :no_content
  end

  test "accepts video_play event" do
    cookies[:_sp_vid] = "550e8400-e29b-41d4-a716-446655440000"

    assert_enqueued_with(job: RecordAnalyticsEventJob) do
      post analytics_track_path,
        params: { event_type: "video_play", page_path: "/", event_data: { duration: 90 } },
        as: :json
    end

    assert_response :no_content
  end

  test "accepts video_progress event" do
    cookies[:_sp_vid] = "550e8400-e29b-41d4-a716-446655440000"

    assert_enqueued_with(job: RecordAnalyticsEventJob) do
      post analytics_track_path,
        params: { event_type: "video_progress", page_path: "/", event_data: { progress: 50, current_time: 45, duration: 90 } },
        as: :json
    end

    assert_response :no_content
  end

  test "accepts waitlist_submit event" do
    cookies[:_sp_vid] = "550e8400-e29b-41d4-a716-446655440000"

    assert_enqueued_with(job: RecordAnalyticsEventJob) do
      post analytics_track_path,
        params: { event_type: "waitlist_submit", page_path: "/" },
        as: :json
    end

    assert_response :no_content
  end

  test "does not require CSRF token" do
    cookies[:_sp_vid] = "550e8400-e29b-41d4-a716-446655440000"

    post analytics_track_path,
      params: { event_type: "page_view", page_path: "/" },
      as: :json

    assert_response :no_content
  end
end

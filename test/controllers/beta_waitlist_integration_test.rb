require "test_helper"

class BetaWaitlistIntegrationTest < ActionDispatch::IntegrationTest
  test "modal form submits to waitlist endpoint and returns JSON" do
    assert_difference "WaitlistEntry.count", 1 do
      post waitlist_path, params: { email: "newuser@example.com" }, as: :json
    end

    entry = WaitlistEntry.last
    assert_equal "newuser@example.com", entry.email

    # Should return JSON with redirect URL
    assert_response :success
    json = JSON.parse(response.body)
    assert json["redirect_url"].include?("/waitlist/questions/")
  end

  test "duplicate email handling works with JSON" do
    # Create initial entry
    entry = WaitlistEntry.create!(email: "duplicate@example.com")

    # Attempt duplicate submission
    assert_no_difference "WaitlistEntry.count" do
      post waitlist_path, params: { email: "duplicate@example.com" }, as: :json
    end

    # Should return JSON with redirect URL (to continue questions)
    assert_response :success
    json = JSON.parse(response.body)
    assert json["redirect_url"].include?("/waitlist/questions/#{entry.token}")
  end

  test "already completed email shows message" do
    # Create completed entry with unique email
    unique_email = "completed_#{SecureRandom.hex(4)}@example.com"
    entry = WaitlistEntry.create!(email: unique_email, questions_completed_at: Time.current)

    post waitlist_path, params: { email: unique_email }, as: :json

    # Should return JSON with message
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "You're already on the waitlist. We'll be in touch!", json["message"]
  end

  test "invalid email is rejected with JSON error" do
    assert_no_difference "WaitlistEntry.count" do
      post waitlist_path, params: { email: "invalid-email" }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "HTML form still redirects normally" do
    assert_difference "WaitlistEntry.count", 1 do
      post waitlist_path, params: { email: "htmluser@example.com" }
    end

    assert_response :redirect
    assert_redirected_to(/\/waitlist\/questions\//)
  end
end

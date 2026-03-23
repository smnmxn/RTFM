require "test_helper"

class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "confirming with valid token logs user in and redirects" do
    user = User.create!(
      email: "confirm@example.com",
      password: "securepass123",
      password_confirmation: "securepass123"
    )
    user.generate_confirmation_token
    user.save!

    get confirm_email_path(token: user.confirmation_token)

    assert_response :redirect
    user.reload
    assert user.email_confirmed?
    assert_nil user.confirmation_token
  end

  test "confirming with expired token shows error" do
    user = User.create!(
      email: "expired@example.com",
      password: "securepass123",
      password_confirmation: "securepass123"
    )
    user.generate_confirmation_token
    user.confirmation_sent_at = 25.hours.ago
    user.save!

    get confirm_email_path(token: user.confirmation_token)

    assert_redirected_to confirmation_pending_path(email: "expired@example.com")
    assert_match /expired/, flash[:alert]
    assert_not user.reload.email_confirmed?
  end

  test "confirming with invalid token shows error" do
    get confirm_email_path(token: "bogus")

    assert_redirected_to login_path
    assert_match /Invalid/, flash[:alert]
  end

  test "pending page renders" do
    get confirmation_pending_path(email: "test@example.com")

    assert_response :success
    assert_select "p", text: /test@example.com/
  end

  test "resend generates new token and sends email" do
    user = User.create!(
      email: "resend@example.com",
      password: "securepass123",
      password_confirmation: "securepass123"
    )
    user.generate_confirmation_token
    user.save!
    old_token = user.confirmation_token

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post resend_confirmation_path, params: { email: "resend@example.com" }
    end

    assert_redirected_to confirmation_pending_path(email: "resend@example.com")
    assert_not_equal old_token, user.reload.confirmation_token
  end

  test "resend with unknown email still shows success" do
    post resend_confirmation_path, params: { email: "unknown@example.com" }

    assert_redirected_to confirmation_pending_path(email: "unknown@example.com")
    assert_match /Confirmation email sent/, flash[:notice]
  end

  test "resend does not send email for already confirmed user" do
    user = User.create!(
      email: "confirmed@example.com",
      password: "securepass123",
      password_confirmation: "securepass123",
      email_confirmed_at: Time.current
    )

    assert_no_enqueued_jobs do
      post resend_confirmation_path, params: { email: "confirmed@example.com" }
    end

    assert_redirected_to confirmation_pending_path(email: "confirmed@example.com")
  end
end

require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "confirmation email is sent to correct address" do
    user = User.create!(
      email: "mailertest@example.com",
      name: "Test User",
      password: "securepass123",
      password_confirmation: "securepass123"
    )
    user.generate_confirmation_token
    user.save!

    email = UserMailer.confirmation(user)

    assert_equal ["mailertest@example.com"], email.to
    assert_equal "Confirm your email address", email.subject
    assert_match user.confirmation_token, email.body.encoded
  end

  test "confirmation email contains confirmation link" do
    user = User.create!(
      email: "linktest@example.com",
      name: "Link User",
      password: "securepass123",
      password_confirmation: "securepass123"
    )
    user.generate_confirmation_token
    user.save!

    email = UserMailer.confirmation(user)

    assert_match "confirm_email", email.body.encoded
    assert_match user.confirmation_token, email.body.encoded
  end
end

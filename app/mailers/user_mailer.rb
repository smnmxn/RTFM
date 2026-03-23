class UserMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    @confirmation_url = confirm_email_url(token: user.confirmation_token)
    mail(to: user.email, subject: "Confirm your email address")
  end
end

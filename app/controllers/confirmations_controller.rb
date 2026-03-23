class ConfirmationsController < ApplicationController
  skip_before_action :require_authentication

  def show
    user = User.find_by(confirmation_token: params[:token])

    if user.nil?
      redirect_to login_path, alert: "Invalid confirmation link."
    elsif user.confirmation_token_expired?
      redirect_to confirmation_pending_path(email: user.email),
        alert: "This confirmation link has expired. Please request a new one."
    else
      user.confirm_email!
      session[:user_id] = user.id
      redirect_to app_subdomain_url(default_landing_path(user)),
        allow_other_host: true,
        notice: "Email confirmed! Welcome to SupportPages."
    end
  end

  def pending
    @email = params[:email]
  end

  def resend
    user = User.find_by(email: params[:email])

    if user&.needs_confirmation?
      user.generate_confirmation_token
      user.save!
      UserMailer.confirmation(user).deliver_later
    end

    # Always show success to prevent email enumeration
    redirect_to confirmation_pending_path(email: params[:email]),
      notice: "Confirmation email sent. Please check your inbox."
  end
end

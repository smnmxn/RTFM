class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create, :failure ]

  def new
    redirect_to dashboard_path if logged_in?
  end

  def create
    auth = request.env["omniauth.auth"]

    user = User.find_or_create_from_omniauth(auth)
    session[:user_id] = user.id

    redirect_to dashboard_path, notice: "Welcome, #{user.name || user.github_username}!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: "Authentication failed: #{e.message}"
  end

  def failure
    message = params[:message] || "Authentication failed"
    redirect_to login_path, alert: "GitHub authentication failed: #{message}"
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "You have been logged out."
  end
end

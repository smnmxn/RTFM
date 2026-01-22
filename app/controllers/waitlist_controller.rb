class WaitlistController < ApplicationController
  skip_before_action :require_authentication

  def create
    entry = WaitlistEntry.new(email: params[:email])

    if entry.save
      redirect_to login_path, notice: "You're on the list! We'll let you know when invites are available."
    elsif entry.errors[:email].include?("has already been taken")
      redirect_to login_path, notice: "You're already on the waitlist. We'll be in touch!"
    else
      redirect_to login_path, alert: "Please enter a valid email address."
    end
  end
end

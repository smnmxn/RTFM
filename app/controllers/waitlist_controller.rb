class WaitlistController < ApplicationController
  skip_before_action :require_authentication

  def create
    email = params[:email].to_s.downcase.strip
    entry = WaitlistEntry.find_or_initialize_by(email: email)

    if entry.new_record?
      if entry.save
        redirect_to waitlist_questions_path(entry.token)
      else
        redirect_to login_path, alert: "Please enter a valid email address."
      end
    elsif entry.questions_completed_at.nil?
      # Existing entry without completed questions - continue flow
      redirect_to waitlist_questions_path(entry.token)
    else
      # Already completed
      redirect_to login_path, notice: "You're already on the waitlist. We'll be in touch!"
    end
  end
end

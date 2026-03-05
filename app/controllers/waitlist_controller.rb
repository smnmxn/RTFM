class WaitlistController < ApplicationController
  skip_before_action :require_authentication

  def create
    email = params[:email].to_s.downcase.strip
    entry = WaitlistEntry.find_or_initialize_by(email: email)

    if entry.new_record?
      if entry.save
        # Identify the visitor with email
        identify_visitor_with_email(email)
        respond_to do |format|
          format.html { redirect_to waitlist_questions_path(entry.token) }
          format.json { render json: { redirect_url: waitlist_questions_path(entry.token) } }
        end
      else
        respond_to do |format|
          format.html { redirect_to login_path, alert: "Please enter a valid email address." }
          format.json { render json: { error: "Invalid email" }, status: :unprocessable_entity }
        end
      end
    elsif entry.questions_completed_at.nil?
      # Existing entry without completed questions - continue flow
      identify_visitor_with_email(email)
      respond_to do |format|
        format.html { redirect_to waitlist_questions_path(entry.token) }
        format.json { render json: { redirect_url: waitlist_questions_path(entry.token) } }
      end
    else
      # Already completed
      respond_to do |format|
        format.html { redirect_to login_path, notice: "You're already on the waitlist. We'll be in touch!" }
        format.json { render json: { message: "You're already on the waitlist. We'll be in touch!" } }
      end
    end
  end

  private

  def identify_visitor_with_email(email)
    return unless cookies[:_sp_vid].present?

    visitor = Visitor.find_by(visitor_id: cookies[:_sp_vid])
    visitor&.identify!(email: email)
  end
end

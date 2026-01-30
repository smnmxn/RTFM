class WaitlistQuestionsController < ApplicationController
  skip_before_action :require_authentication
  before_action :set_entry

  def show
    if @entry.questions_completed_at.present?
      redirect_to login_path, notice: "You've already completed the waitlist questions."
      return
    end
  end

  def update
    permitted = params.permit(:name, :company, :website, :platform_type, :repo_structure, :vcs_provider, :workflow, :user_base, :completed)

    # Update individual answers
    answers = permitted.to_h.except("completed")
    @entry.assign_attributes(answers) if answers.present?

    # Mark as completed if final submission
    if permitted[:completed] == "true"
      @entry.questions_completed_at = Time.current
    end

    @entry.save!
    head :ok
  end

  private

  def set_entry
    @entry = WaitlistEntry.find_by(token: params[:token])

    unless @entry
      redirect_to login_path, alert: "Invalid waitlist link."
    end
  end
end

class DashboardController < ApplicationController
  def show
    # Force first-time users into onboarding
    if current_user.needs_onboarding?
      redirect_to new_onboarding_project_path
      return
    end

    # Resume incomplete onboarding
    if current_user.onboarding_in_progress?
      project = current_user.current_onboarding_project
      redirect_to send("#{project.onboarding_step}_onboarding_project_path", project)
      return
    end

    @projects = current_user.projects.order(updated_at: :desc)
  end
end

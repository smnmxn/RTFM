class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create, :failure ]

  def new
    redirect_to default_landing_path if logged_in?
  end

  def create
    auth = request.env["omniauth.auth"]

    user = User.find_or_create_from_omniauth(auth)
    session[:user_id] = user.id

    redirect_to default_landing_path(user), notice: "Welcome, #{user.name || user.github_username}!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: "Authentication failed: #{e.message}"
  end

  private

  def default_landing_path(user = current_user)
    # Resume incomplete onboarding if no completed projects
    if user.onboarding_in_progress?
      completed_projects = user.projects.where(onboarding_step: nil)
      if completed_projects.empty?
        project = user.current_onboarding_project
        if Project::ONBOARDING_STEPS.include?(project.onboarding_step)
          return send("#{project.onboarding_step}_onboarding_project_path", project)
        else
          project.complete_onboarding!
          return project_path(project)
        end
      end
    end

    projects = user.projects.where(onboarding_step: nil)

    case projects.count
    when 0
      new_onboarding_project_path
    when 1
      project_path(projects.first)
    else
      projects_path
    end
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

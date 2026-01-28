class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create, :failure, :destroy ]

  def new
    redirect_to app_subdomain_url(default_landing_path), allow_other_host: true if logged_in?
  end

  def create
    auth = request.env["omniauth.auth"]

    user = User.find_by(github_uid: auth.uid)

    if user
      # Existing user - update credentials and log in
      user.update!(
        github_token: auth.credentials.token,
        github_username: auth.info.nickname,
        name: auth.info.name,
        email: auth.info.email
      )
      session[:user_id] = user.id
      session.delete(:invite_token)
      redirect_to app_subdomain_url(default_landing_path(user)), allow_other_host: true, notice: "Welcome back, #{user.name || user.github_username}!"
    else
      # New user - require valid invite
      invite = Invite.available.find_by(token: session[:invite_token])

      if invite.nil?
        redirect_to login_path, alert: "Signup requires an invite. Please use an invite link to create an account."
        return
      end

      user = User.create!(
        github_uid: auth.uid,
        github_token: auth.credentials.token,
        github_username: auth.info.nickname,
        name: auth.info.name,
        email: auth.info.email
      )

      invite.redeem!(user)
      session.delete(:invite_token)
      session[:user_id] = user.id

      redirect_to app_subdomain_url(default_landing_path(user)), allow_other_host: true, notice: "Welcome, #{user.name || user.github_username}!"
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: "Authentication failed: #{e.message}"
  end

  def failure
    message = params[:message] || "Authentication failed"
    redirect_to login_path, alert: "GitHub authentication failed: #{message}"
  end

  def destroy
    session.delete(:user_id)
    redirect_to bare_domain_url("/"), allow_other_host: true, notice: "You have been logged out."
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
end

class SessionsController < ApplicationController
  include Trackable

  skip_before_action :require_authentication, only: [ :new, :create, :failure, :destroy, :create_with_password, :register ]

  def new
    redirect_to app_subdomain_url(default_landing_path), allow_other_host: true if logged_in?
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.find_from_omniauth(auth)

    if user
      log_in_user(user)
    else
      handle_new_user_signup(auth)
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to login_path, alert: "Authentication failed: #{e.message}"
  end

  def create_with_password
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      log_in_user(user)
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def register
    invite = Invite.available.find_by(token: session[:invite_token])
    if invite_required? && invite.nil?
      redirect_to login_path, alert: "Sign up is currently invite-only. Please request an invite to get started."
      return
    end

    user = User.new(
      email: params[:email],
      name: params[:name],
      password: params[:password],
      password_confirmation: params[:password_confirmation]
    )

    if user.save
      invite&.redeem!(user)
      session.delete(:invite_token)
      log_in_user(user)
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def failure
    message = params[:message] || "Authentication failed"
    redirect_to login_path, alert: "Authentication failed: #{message}"
  end

  def destroy
    session.delete(:user_id)
    redirect_to bare_domain_url("/"), allow_other_host: true, notice: "You have been logged out."
  end

  private

  def log_in_user(user)
    session[:user_id] = user.id
    session.delete(:invite_token)

    identify_visitor(user)

    redirect_path = session.delete(:redirect_after_login) || default_landing_path(user)
    redirect_to app_subdomain_url(redirect_path), allow_other_host: true, notice: "Welcome back, #{user.name || user.email}!"
  end

  def handle_new_user_signup(auth)
    invite = Invite.available.find_by(token: session[:invite_token])

    if invite_required? && invite.nil?
      redirect_to login_path, alert: "Sign up is currently invite-only. Please request an invite to get started."
      return
    end

    user = User.create_from_omniauth!(auth)
    invite&.redeem!(user)
    session.delete(:invite_token)
    session[:user_id] = user.id

    identify_visitor(user)

    redirect_to app_subdomain_url(default_landing_path(user)), allow_other_host: true, notice: "Welcome, #{user.name || user.email}!"
  end

  def invite_required?
    ENV.fetch("REQUIRE_INVITE", "false") == "true"
  end

  def identify_visitor(user)
    return unless cookies[:_sp_vid].present?

    visitor = Visitor.find_by(visitor_id: cookies[:_sp_vid])
    visitor&.identify!(
      email: user.email,
      name: user.name,
      user_id: user.id
    )
  end

  def identify_visitor_with_email(email)
    return unless cookies[:_sp_vid].present?

    visitor = Visitor.find_by(visitor_id: cookies[:_sp_vid])
    visitor&.identify!(email: email)
  end

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

class ApplicationController < ActionController::Base
  include TestSessionHelper
  include ProductAnalytics

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_authentication

  helper_method :current_user, :logged_in?, :app_subdomain_url, :bare_domain_url

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_authentication
    # Skip auth check for test login endpoint
    return if Rails.env.test? && params[:action] == "test_login"

    unless logged_in?
      session[:redirect_after_login] = request.path if request.get?
      redirect_to bare_domain_url("/login"), allow_other_host: true, alert: "Please sign in to continue."
    end
  end

  def require_admin
    unless current_user&.admin?
      redirect_to projects_path, alert: "You don't have permission to access that page."
    end
  end

  def require_pro
    unless current_user&.pro_or_above?
      redirect_to billing_path, alert: "This feature requires a Pro plan."
    end
  end

  def base_domain
    Rails.application.config.x.base_domain
  end

  def app_subdomain_url(path = "/")
    port = request.port unless [ 80, 443 ].include?(request.port)
    host = "app.#{base_domain.split(':').first}"
    host_with_port = port ? "#{host}:#{port}" : host
    "#{request.protocol}#{host_with_port}#{path}"
  end

  def bare_domain_url(path = "/")
    port = request.port unless [ 80, 443 ].include?(request.port)
    host = base_domain.split(":").first
    host_with_port = port ? "#{host}:#{port}" : host
    "#{request.protocol}#{host_with_port}#{path}"
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
      choose_plan_path
    when 1
      project_path(projects.first)
    else
      projects_path
    end
  end

  def rollbar_custom_data
    {
      project_id: @project&.id,
      project_slug: @project&.slug
    }
  end
end

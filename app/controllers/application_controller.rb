class ApplicationController < ActionController::Base
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
    unless logged_in?
      redirect_to bare_domain_url("/login"), allow_other_host: true, alert: "Please sign in with GitHub to continue."
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

  def rollbar_custom_data
    {
      project_id: @project&.id,
      project_slug: @project&.slug
    }
  end
end

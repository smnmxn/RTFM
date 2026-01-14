class GithubAppController < ApplicationController
  before_action :require_authentication

  def install
    # Store return path for after installation
    session[:github_app_return_to] = params[:return_to] || dashboard_path

    # Redirect to GitHub App installation page
    install_url = "https://github.com/apps/#{github_app_slug}/installations/new"
    redirect_to install_url, allow_other_host: true
  end

  def callback
    installation_id = params[:installation_id]
    setup_action = params[:setup_action]

    return_path = session.delete(:github_app_return_to) || dashboard_path

    if installation_id.blank?
      redirect_to return_path, alert: "GitHub App installation was cancelled."
      return
    end

    # Sync installation from GitHub
    installation = sync_installation(installation_id)

    if installation
      redirect_to return_path, notice: "GitHub App installed successfully! You can now connect repositories."
    else
      redirect_to return_path, alert: "Failed to configure GitHub App. Please try again."
    end
  end

  private

  def github_app_slug
    ENV.fetch("GITHUB_APP_SLUG")
  end

  def sync_installation(installation_id)
    # First check if the webhook already created this installation
    existing = GithubAppInstallation.find_by(github_installation_id: installation_id.to_i)
    return existing if existing

    # Fall back to fetching from GitHub API
    app_client = GithubAppService.app_client
    installation_data = app_client.installation(installation_id)

    GithubAppInstallation.create!(
      github_installation_id: installation_id.to_i,
      account_login: installation_data.account.login,
      account_type: installation_data.account.type,
      account_id: installation_data.account.id
    )
  rescue Octokit::Error => e
    Rails.logger.error "[GithubAppController] Failed to sync installation: #{e.message}"
    # One more check in case webhook arrived while we were making API call
    GithubAppInstallation.find_by(github_installation_id: installation_id.to_i)
  end
end

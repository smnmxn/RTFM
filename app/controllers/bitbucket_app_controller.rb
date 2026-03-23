class BitbucketAppController < ApplicationController
  before_action :require_authentication

  def install
    session[:bitbucket_app_return_to] = params[:return_to] || projects_path

    callback_url = app_subdomain_url("/bitbucket_app/callback")
    session[:bitbucket_callback_url] = callback_url

    authorize_url = "https://bitbucket.org/site/oauth2/authorize?" + {
      client_id: bitbucket_client_id,
      response_type: "code",
      scope: "account repository pullrequest webhook",
      redirect_uri: callback_url
    }.to_query

    redirect_to authorize_url, allow_other_host: true
  end

  def callback
    code = params[:code]
    return_path = session.delete(:bitbucket_app_return_to) || projects_path
    return_url = app_subdomain_url(return_path)

    if code.blank?
      redirect_to return_url, allow_other_host: true, alert: "Bitbucket authorization was cancelled."
      return
    end

    begin
      callback_url = session.delete(:bitbucket_callback_url) || bitbucket_callback_url
      Rails.logger.info "[BitbucketAppController] Exchanging code with redirect_uri: #{callback_url}"
      token_data = Vcs::Bitbucket::TokenManager.exchange_code(code, callback_url)
      connections = sync_workspaces(token_data)

      if connections.any?
        redirect_to return_url, allow_other_host: true, notice: "Bitbucket connected successfully! You can now connect repositories."
      else
        redirect_to return_url, allow_other_host: true, alert: "No Bitbucket workspaces found. Please ensure you have access to at least one workspace."
      end
    rescue => e
      Rails.logger.error "[BitbucketAppController] OAuth callback failed: #{e.message}"
      redirect_to return_url, allow_other_host: true, alert: "Failed to connect Bitbucket. Please try again."
    end
  end

  private

  def bitbucket_client_id
    ENV.fetch("BITBUCKET_CLIENT_ID")
  end

  def bitbucket_callback_url
    bitbucket_app_callback_url
  end

  def sync_workspaces(token_data)
    client = Vcs::Bitbucket::Client.new(access_token: token_data[:access_token])
    workspaces = client.paginate("workspaces", role: "member")

    connections = []

    workspaces.each do |ws|
      connection = BitbucketConnection.find_or_initialize_by(
        user: current_user,
        workspace_slug: ws["slug"]
      )

      connection.assign_attributes(
        workspace_name: ws["name"],
        workspace_uuid: ws["uuid"],
        access_token: token_data[:access_token],
        refresh_token: token_data[:refresh_token],
        token_expires_at: token_data[:expires_at],
        scopes: token_data[:scopes],
        suspended_at: nil
      )

      connection.save!
      connections << connection
    end

    # Create/update user identity for Bitbucket
    identity = current_user.user_identities.find_or_initialize_by(provider: "bitbucket")
    identity.update!(
      uid: workspaces.first&.dig("uuid") || current_user.id.to_s,
      token: token_data[:access_token],
      refresh_token: token_data[:refresh_token],
      token_expires_at: token_data[:expires_at]
    )

    connections
  end
end

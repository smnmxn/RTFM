require "jwt"
require "octokit"

class GithubAppService
  TOKEN_CACHE_PREFIX = "github_app_token"
  TOKEN_EXPIRY_BUFFER = 5.minutes

  class << self
    def installation_token(installation_id)
      Vcs::Github::AppService.installation_token(installation_id)
    end

    def client_for_installation(installation_id)
      Vcs::Github::AppService.client_for_installation(installation_id)
    end

    def app_client
      Vcs::Github::AppService.app_client
    end
  end

  def installation_token(installation_id)
    Vcs::Github::AppService.new.installation_token(installation_id)
  end

  def client_for_installation(installation_id)
    Vcs::Github::AppService.new.client_for_installation(installation_id)
  end

  def app_client
    Vcs::Github::AppService.new.app_client
  end

  def verify_webhook_signature(payload, signature)
    Vcs::Github::AppService.new.verify_webhook_signature(payload, signature)
  end
end

require "jwt"
require "octokit"

class GithubAppService
  TOKEN_CACHE_PREFIX = "github_app_token"
  TOKEN_EXPIRY_BUFFER = 5.minutes

  class << self
    def installation_token(installation_id)
      new.installation_token(installation_id)
    end

    def client_for_installation(installation_id)
      new.client_for_installation(installation_id)
    end

    def app_client
      new.app_client
    end
  end

  def installation_token(installation_id)
    cached = Rails.cache.read(cache_key(installation_id))
    if cached && cached[:expires_at] > Time.current + TOKEN_EXPIRY_BUFFER
      return cached[:token]
    end

    token_response = app_client.create_app_installation_access_token(installation_id)

    Rails.cache.write(
      cache_key(installation_id),
      { token: token_response.token, expires_at: token_response.expires_at },
      expires_in: 50.minutes
    )

    token_response.token
  end

  def client_for_installation(installation_id)
    token = installation_token(installation_id)
    Octokit::Client.new(access_token: token)
  end

  def app_client
    Octokit::Client.new(bearer_token: generate_jwt)
  end

  def verify_webhook_signature(payload, signature)
    return false if signature.blank?

    secret = webhook_secret
    return false if secret.blank?

    expected = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      secret,
      payload
    )

    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  private

  def cache_key(installation_id)
    "#{TOKEN_CACHE_PREFIX}:#{installation_id}"
  end

  def generate_jwt
    private_key = OpenSSL::PKey::RSA.new(app_private_key)

    payload = {
      iat: Time.current.to_i - 60,
      exp: Time.current.to_i + (10 * 60),
      iss: app_id
    }

    JWT.encode(payload, private_key, "RS256")
  end

  def app_id
    ENV.fetch("GITHUB_APP_ID")
  end

  def app_private_key
    # Handle both actual newlines and escaped \n in env var
    ENV.fetch("GITHUB_APP_PRIVATE_KEY").gsub('\n', "\n")
  end

  def webhook_secret
    ENV["GITHUB_APP_WEBHOOK_SECRET"]
  end
end

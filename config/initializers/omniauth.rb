# Override callback_url to point to app. subdomain
module OmniAuth
  module Strategies
    class GitHub
      def callback_url
        base_domain = Rails.application.config.x.base_domain
        protocol = request.scheme
        "#{protocol}://app.#{base_domain}/auth/github/callback"
      end
    end
  end
end

module OmniAuth
  module Strategies
    class GoogleOauth2
      def callback_url
        base_domain = Rails.application.config.x.base_domain
        protocol = request.scheme
        "#{protocol}://app.#{base_domain}/auth/google_oauth2/callback"
      end
    end
  end
end

module OmniAuth
  module Strategies
    class Apple
      def callback_url
        base_domain = Rails.application.config.x.base_domain
        protocol = request.scheme
        "#{protocol}://app.#{base_domain}/auth/apple/callback"
      end
    end
  end
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           ENV["GITHUB_CLIENT_ID"],
           ENV["GITHUB_CLIENT_SECRET"],
           scope: "read:user,user:email"

  if ENV["GOOGLE_CLIENT_ID"].present? || Rails.env.test?
    provider :google_oauth2,
             ENV.fetch("GOOGLE_CLIENT_ID", "test"),
             ENV.fetch("GOOGLE_CLIENT_SECRET", "test"),
             scope: "email,profile"
  end

  if ENV["APPLE_CLIENT_ID"].present? || Rails.env.test?
    provider :apple,
             ENV.fetch("APPLE_CLIENT_ID", "test"),
             "",
             scope: "email name",
             team_id: ENV.fetch("APPLE_TEAM_ID", "test"),
             key_id: ENV.fetch("APPLE_KEY_ID", "test"),
             pem: ENV.fetch("APPLE_PRIVATE_KEY", "test")
  end
end

OmniAuth.config.on_failure = Proc.new do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end

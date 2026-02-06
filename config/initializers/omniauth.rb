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

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
           ENV["GITHUB_CLIENT_ID"],
           ENV["GITHUB_CLIENT_SECRET"],
           scope: "read:user,user:email"
end

OmniAuth.config.on_failure = Proc.new do |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
end

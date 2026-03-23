require "faraday"
require "json"
require_relative "../error"

module Vcs
  module Bitbucket
    class TokenManager
      TOKEN_URL = "https://bitbucket.org/site/oauth2/access_token"
      TOKEN_CACHE_PREFIX = "bitbucket_token"
      EXPIRY_BUFFER = 5.minutes

      class << self
        def ensure_fresh_token!(connection)
          new.ensure_fresh_token!(connection)
        end

        def exchange_code(code, redirect_uri)
          new.exchange_code(code, redirect_uri)
        end
      end

      def ensure_fresh_token!(connection)
        # Check cache first
        cached = Rails.cache.read(cache_key(connection.id))
        if cached && cached[:expires_at] > Time.current + EXPIRY_BUFFER
          return cached[:token]
        end

        # Check if stored token is still valid
        unless connection.token_expired?
          cache_token(connection)
          return connection.access_token
        end

        # Refresh the token
        refresh_token!(connection)
      end

      def exchange_code(code, redirect_uri)
        response = token_request(
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri
        )

        parse_token_response(response)
      end

      private

      def refresh_token!(connection)
        response = token_request(
          grant_type: "refresh_token",
          refresh_token: connection.refresh_token
        )

        token_data = parse_token_response(response)

        connection.update!(
          access_token: token_data[:access_token],
          refresh_token: token_data[:refresh_token],
          token_expires_at: token_data[:expires_at]
        )

        cache_token(connection)
        connection.access_token
      end

      def token_request(params)
        conn = Faraday.new do |f|
          f.request :url_encoded
          f.request :authorization, :basic, client_id, client_secret
          f.adapter Faraday.default_adapter
        end

        conn.post(TOKEN_URL, params)
      end

      def parse_token_response(response)
        data = JSON.parse(response.body)

        unless response.status == 200
          raise Vcs::AuthenticationError, "Bitbucket token request failed: #{data["error_description"] || data["error"]}"
        end

        {
          access_token: data["access_token"],
          refresh_token: data["refresh_token"],
          expires_at: Time.current + data["expires_in"].to_i.seconds,
          scopes: data["scopes"]
        }
      end

      def cache_token(connection)
        Rails.cache.write(
          cache_key(connection.id),
          { token: connection.access_token, expires_at: connection.token_expires_at },
          expires_in: [connection.token_expires_at - Time.current - EXPIRY_BUFFER, 0].max
        )
      end

      def cache_key(connection_id)
        "#{TOKEN_CACHE_PREFIX}:#{connection_id}"
      end

      def client_id
        ENV.fetch("BITBUCKET_CLIENT_ID")
      end

      def client_secret
        ENV.fetch("BITBUCKET_CLIENT_SECRET")
      end
    end
  end
end

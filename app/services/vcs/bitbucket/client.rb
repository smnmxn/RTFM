require "faraday"
require "json"

module Vcs
  module Bitbucket
    class Client
      BASE_URL = "https://api.bitbucket.org/2.0"

      attr_reader :access_token

      def initialize(access_token:)
        @access_token = access_token
      end

      def get(path, params = {})
        response = connection.get(path, params)
        handle_response(response)
      end

      def post(path, body = {})
        response = connection.post(path) do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        handle_response(response)
      end

      def delete(path)
        response = connection.delete(path)
        return nil if response.status == 204
        handle_response(response)
      end

      # Follows Bitbucket's cursor-based pagination, yielding each page's values
      def paginate(path, params = {}, &block)
        results = []
        url = path

        loop do
          data = get(url, params)
          values = data["values"] || []

          if block_given?
            values.each { |v| yield v }
          else
            results.concat(values)
          end

          url = data["next"]
          break unless url

          # After first request, params are embedded in the next URL
          params = {}
          # Convert absolute URL to relative path (strip base URL and leading slash)
          url = url.sub("#{BASE_URL}/", "")
        end

        results unless block_given?
      end

      private

      def connection
        @connection ||= Faraday.new(url: BASE_URL) do |f|
          f.request :authorization, "Bearer", access_token
          f.response :raise_error
          f.adapter Faraday.default_adapter
        end
      end

      def handle_response(response)
        body = response.body
        return nil if body.nil? || body.empty?

        content_type = response.headers["content-type"].to_s
        if content_type.include?("application/json")
          JSON.parse(body)
        else
          body
        end
      end
    end
  end
end

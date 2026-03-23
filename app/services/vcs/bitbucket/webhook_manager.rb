module Vcs
  module Bitbucket
    class WebhookManager
      EVENTS = [
        "pullrequest:fulfilled",
        "repo:push"
      ].freeze

      def register(connection, repo_slug, callback_url, secret)
        token = TokenManager.ensure_fresh_token!(connection)
        client = Client.new(access_token: token)

        workspace, slug = repo_slug.split("/", 2)

        body = {
          description: "RTFM webhook",
          url: callback_url,
          active: true,
          events: EVENTS,
          secret: secret
        }

        response = client.post("repositories/#{workspace}/#{slug}/hooks", body)

        {
          uuid: response["uuid"],
          url: response.dig("links", "self", "href")
        }
      end

      def delete(connection, repo_slug, webhook_uuid)
        token = TokenManager.ensure_fresh_token!(connection)
        client = Client.new(access_token: token)

        workspace, slug = repo_slug.split("/", 2)

        client.delete("repositories/#{workspace}/#{slug}/hooks/#{webhook_uuid}")
      end
    end
  end
end

module Vcs
  module Github
    class WebhookHandler
      def initialize(payload:, event_type:)
        @payload = payload
        @event_type = event_type
        @data = JSON.parse(payload)
      end

      def process
        case @event_type
        when "installation"
          handle_installation_event
        when "pull_request"
          handle_pull_request_event
        else
          { action: :ignore }
        end
      end

      private

      def handle_installation_event
        action = @data["action"]
        installation = @data["installation"]

        case action
        when "created"
          {
            action: :installation_created,
            installation_id: installation["id"],
            account_login: installation.dig("account", "login"),
            account_type: installation.dig("account", "type"),
            account_id: installation.dig("account", "id")
          }
        when "deleted"
          {
            action: :installation_deleted,
            installation_id: installation["id"],
            account_login: installation.dig("account", "login")
          }
        when "suspend"
          {
            action: :installation_suspended,
            installation_id: installation["id"],
            account_login: installation.dig("account", "login")
          }
        when "unsuspend"
          {
            action: :installation_unsuspended,
            installation_id: installation["id"],
            account_login: installation.dig("account", "login")
          }
        else
          { action: :ignore }
        end
      end

      def handle_pull_request_event
        action = @data["action"]
        pull_request = @data["pull_request"]

        unless action == "closed" && pull_request&.dig("merged")
          return { action: :ignore }
        end

        {
          action: :pull_request_merged,
          repo: @data.dig("repository", "full_name"),
          pr_number: pull_request["number"],
          pr_url: pull_request["html_url"],
          pr_title: pull_request["title"],
          pr_body: pull_request["body"],
          merge_commit_sha: pull_request["merge_commit_sha"],
          target_branch: pull_request.dig("base", "ref")
        }
      end
    end
  end
end

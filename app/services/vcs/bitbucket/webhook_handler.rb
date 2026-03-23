module Vcs
  module Bitbucket
    class WebhookHandler
      def initialize(payload:, event_type:)
        @payload = payload
        @event_type = event_type
        @data = JSON.parse(payload)
      end

      def process
        case @event_type
        when "pullrequest:fulfilled"
          handle_pull_request_merged
        when "repo:push"
          handle_push
        else
          { action: :ignore }
        end
      end

      private

      def handle_pull_request_merged
        pr = @data["pullrequest"]
        repo = @data["repository"]

        {
          action: :pull_request_merged,
          repo: repo["full_name"],
          pr_number: pr["id"],
          pr_url: pr.dig("links", "html", "href"),
          pr_title: pr["title"],
          pr_body: pr["description"],
          merge_commit_sha: pr.dig("merge_commit", "hash"),
          target_branch: pr.dig("destination", "branch", "name")
        }
      end

      def handle_push
        repo = @data["repository"]
        changes = @data.dig("push", "changes") || []

        commits = changes.flat_map do |change|
          (change["commits"] || []).map do |c|
            {
              sha: c["hash"],
              message: c["message"],
              author: c.dig("author", "raw")
            }
          end
        end

        {
          action: :push,
          repo: repo["full_name"],
          commits: commits
        }
      end
    end
  end
end

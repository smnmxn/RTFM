require "octokit"

module Vcs
  module Github
    class Adapter < Vcs::Base
      # Auth

      def authenticate(installation_id)
        wrap_errors do
          AppService.client_for_installation(installation_id)
        end
      end

      def installation_token(installation_id)
        wrap_errors do
          AppService.installation_token(installation_id)
        end
      end

      # Repos

      def list_repositories(installation, per_page: 100)
        wrap_errors do
          response = installation.repositories(per_page: per_page)
          response.repositories.map { |r| Normalizer.repository(r, installation) }
        end
      end

      def repository_info(repo_id, client: nil)
        wrap_errors do
          c = client || AppService.app_client
          repo = c.repository(repo_id)
          Normalizer.repository(repo)
        end
      end

      def branches(repo_id, installation_id:, per_page: 100)
        wrap_errors do
          client = AppService.client_for_installation(installation_id)
          client.branches(repo_id, per_page: per_page).map(&:name)
        end
      end

      def default_branch(repo_id, installation_id:)
        wrap_errors do
          client = AppService.client_for_installation(installation_id)
          repo = client.repository(repo_id)
          repo.default_branch
        end
      end

      # Diffs

      def compare(repo_id, base_sha, head_sha, client: nil, accept: nil)
        wrap_errors do
          c = client || AppService.app_client
          opts = {}
          opts[:accept] = accept if accept
          c.compare(repo_id, base_sha, head_sha, opts)
        end
      end

      def pull_request_diff(repo_id, pr_number, client: nil, accept: nil)
        wrap_errors do
          c = client || AppService.app_client
          opts = {}
          opts[:accept] = accept if accept
          c.pull_request(repo_id, pr_number, opts)
        end
      end

      def commit_diff(repo_id, sha, client: nil, accept: nil)
        wrap_errors do
          c = client || AppService.app_client
          opts = {}
          opts[:accept] = accept if accept
          c.commit(repo_id, sha, opts)
        end
      end

      # Listing

      def pull_requests(repo_id, client: nil, state: "closed", sort: "updated", direction: "desc", page: 1, per_page: 30)
        wrap_errors do
          c = client || AppService.app_client
          prs = c.pull_requests(repo_id, state: state, sort: sort, direction: direction, page: page, per_page: per_page)
          prs.map { |pr| Normalizer.pull_request(pr) }
        end
      end

      def commits(repo_id, client: nil, page: 1, per_page: 30)
        wrap_errors do
          c = client || AppService.app_client
          raw_commits = c.commits(repo_id, page: page, per_page: per_page)
          raw_commits.map { |commit| Normalizer.commit(commit) }
        end
      end

      # Webhooks

      def verify_webhook(payload, signature, secret = nil)
        AppService.new.verify_webhook_signature(payload, signature)
      end

      # URLs

      def clone_url(repo_id, token)
        "https://x-access-token:#{token}@github.com/#{repo_id}.git"
      end

      def web_url(repo_id)
        "https://github.com/#{repo_id}"
      end

      def pull_request_url(repo_id, number)
        "https://github.com/#{repo_id}/pull/#{number}"
      end

      def commit_url(repo_id, sha)
        "https://github.com/#{repo_id}/commit/#{sha}"
      end

      # Identity

      def provider_name
        :github
      end

      private

      def wrap_errors
        yield
      rescue Octokit::Unauthorized, Octokit::Forbidden => e
        raise Vcs::AuthenticationError, e.message
      rescue Octokit::NotFound => e
        raise Vcs::NotFoundError, e.message
      rescue Octokit::TooManyRequests => e
        raise Vcs::RateLimitError, e.message
      rescue Octokit::Error => e
        raise Vcs::ProviderError, e.message
      end
    end
  end
end

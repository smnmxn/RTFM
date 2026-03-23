require_relative "../error"

module Vcs
  module Bitbucket
    class Adapter < Vcs::Base
      # Auth

      def authenticate(connection_id)
        wrap_errors do
          connection = find_connection(connection_id)
          token = TokenManager.ensure_fresh_token!(connection)
          Client.new(access_token: token)
        end
      end

      def installation_token(connection_id)
        wrap_errors do
          connection = find_connection(connection_id)
          TokenManager.ensure_fresh_token!(connection)
        end
      end

      # Repos

      def list_repositories(connection, per_page: 100)
        wrap_errors do
          token = TokenManager.ensure_fresh_token!(connection)
          client = Client.new(access_token: token)

          client.paginate(
            "repositories/#{connection.workspace_slug}",
            role: "member",
            pagelen: [per_page, 100].min
          ).map { |r| Normalizer.repository(r, connection) }
        end
      end

      def repository_info(repo_id, client: nil)
        wrap_errors do
          c = client || default_client
          workspace, slug = repo_id.split("/", 2)
          data = c.get("repositories/#{workspace}/#{slug}")
          Normalizer.repository(data)
        end
      end

      def branches(repo_id, installation_id:, per_page: 100)
        wrap_errors do
          client = authenticate(installation_id)
          workspace, slug = repo_id.split("/", 2)

          client.paginate(
            "repositories/#{workspace}/#{slug}/refs/branches",
            pagelen: [per_page, 100].min
          ).map { |b| b["name"] }
        end
      end

      def default_branch(repo_id, installation_id:)
        wrap_errors do
          client = authenticate(installation_id)
          workspace, slug = repo_id.split("/", 2)
          data = client.get("repositories/#{workspace}/#{slug}")
          data.dig("mainbranch", "name") || "main"
        end
      end

      # Diffs

      def compare(repo_id, base_sha, head_sha, client: nil, accept: nil)
        wrap_errors do
          c = client || default_client
          workspace, slug = repo_id.split("/", 2)
          c.get("repositories/#{workspace}/#{slug}/diff/#{base_sha}..#{head_sha}")
        end
      end

      def pull_request_diff(repo_id, pr_number, client: nil, accept: nil)
        wrap_errors do
          c = client || default_client
          workspace, slug = repo_id.split("/", 2)
          c.get("repositories/#{workspace}/#{slug}/pullrequests/#{pr_number}/diff")
        end
      end

      def commit_diff(repo_id, sha, client: nil, accept: nil)
        wrap_errors do
          c = client || default_client
          workspace, slug = repo_id.split("/", 2)
          c.get("repositories/#{workspace}/#{slug}/diff/#{sha}")
        end
      end

      # Listing

      def pull_requests(repo_id, client: nil, state: "closed", sort: "updated", direction: "desc", page: 1, per_page: 30)
        wrap_errors do
          c = client || default_client
          workspace, slug = repo_id.split("/", 2)

          # Map GitHub states to Bitbucket states
          bb_state = case state
          when "closed" then "MERGED"
          when "open" then "OPEN"
          when "all" then ""
          else "MERGED"
          end

          params = { pagelen: per_page, page: page }
          params[:state] = bb_state if bb_state.present?
          params[:sort] = "-updated_on" if sort == "updated" && direction == "desc"

          data = c.get("repositories/#{workspace}/#{slug}/pullrequests", params)
          (data["values"] || []).map { |pr| Normalizer.pull_request(pr) }
        end
      end

      def commits(repo_id, client: nil, page: 1, per_page: 30)
        wrap_errors do
          c = client || default_client
          workspace, slug = repo_id.split("/", 2)

          data = c.get("repositories/#{workspace}/#{slug}/commits", pagelen: per_page, page: page)
          (data["values"] || []).map { |commit| Normalizer.commit(commit) }
        end
      end

      # Webhooks

      def verify_webhook(payload, signature, secret = nil)
        return false if signature.blank?

        webhook_secret = secret || ENV["BITBUCKET_WEBHOOK_SECRET"]
        return false if webhook_secret.blank?

        expected = "sha256=" + OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new("sha256"),
          webhook_secret,
          payload
        )

        ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end

      # URLs

      def clone_url(repo_id, token)
        "https://x-token-auth:#{token}@bitbucket.org/#{repo_id}.git"
      end

      def web_url(repo_id)
        "https://bitbucket.org/#{repo_id}"
      end

      def pull_request_url(repo_id, number)
        "https://bitbucket.org/#{repo_id}/pull-requests/#{number}"
      end

      def commit_url(repo_id, sha)
        "https://bitbucket.org/#{repo_id}/commits/#{sha}"
      end

      # Identity

      def provider_name
        :bitbucket
      end

      private

      def find_connection(connection_id)
        BitbucketConnection.find(connection_id)
      rescue ActiveRecord::RecordNotFound
        raise Vcs::NotFoundError, "Bitbucket connection #{connection_id} not found"
      end

      def default_client
        raise Vcs::AuthenticationError, "Bitbucket adapter requires an authenticated client"
      end

      def wrap_errors
        yield
      rescue Faraday::UnauthorizedError, Faraday::ForbiddenError => e
        raise Vcs::AuthenticationError, e.message
      rescue Faraday::ResourceNotFound => e
        raise Vcs::NotFoundError, e.message
      rescue Faraday::TooManyRequestsError => e
        raise Vcs::RateLimitError, e.message
      rescue Faraday::Error => e
        raise Vcs::ProviderError, e.message
      end
    end
  end
end

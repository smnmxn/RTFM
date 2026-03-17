module Vcs
  class Base
    # Auth
    def authenticate(installation_id)
      raise NotImplementedError
    end

    def installation_token(installation_id)
      raise NotImplementedError
    end

    # Repos
    def list_repositories(installation, per_page: 100)
      raise NotImplementedError
    end

    def repository_info(repo_id)
      raise NotImplementedError
    end

    def branches(repo_id, installation_id:, per_page: 100)
      raise NotImplementedError
    end

    def default_branch(repo_id, installation_id:)
      raise NotImplementedError
    end

    # Diffs
    def compare(repo_id, base_sha, head_sha, client: nil, accept: nil)
      raise NotImplementedError
    end

    def pull_request_diff(repo_id, pr_number, client: nil, accept: nil)
      raise NotImplementedError
    end

    def commit_diff(repo_id, sha, client: nil, accept: nil)
      raise NotImplementedError
    end

    # Listing
    def pull_requests(repo_id, client: nil, state: "closed", sort: "updated", direction: "desc", page: 1, per_page: 30)
      raise NotImplementedError
    end

    def commits(repo_id, client: nil, page: 1, per_page: 30)
      raise NotImplementedError
    end

    # Webhooks
    def verify_webhook(payload, signature, secret)
      raise NotImplementedError
    end

    # URLs
    def clone_url(repo_id, token)
      raise NotImplementedError
    end

    def web_url(repo_id)
      raise NotImplementedError
    end

    def pull_request_url(repo_id, number)
      raise NotImplementedError
    end

    def commit_url(repo_id, sha)
      raise NotImplementedError
    end

    # Identity
    def provider_name
      raise NotImplementedError
    end
  end
end

require "octokit"

class GithubRepositoriesService
  Result = Struct.new(:success?, :repositories, :error, keyword_init: true)

  def initialize(user)
    @user = user
    @client = Octokit::Client.new(access_token: user.github_token, auto_paginate: false)
  end

  def call(page: 1, per_page: 30)
    repos = @client.repos(
      nil,
      page: page,
      per_page: per_page,
      sort: :pushed,
      affiliation: "owner,collaborator,organization_member"
    )

    # Filter to repos with admin permission (required for webhook creation)
    admin_repos = repos.select { |repo| repo.permissions&.admin }

    Result.new(
      success?: true,
      repositories: admin_repos.map { |r| format_repo(r) }
    )
  rescue Octokit::Unauthorized, Octokit::Forbidden => e
    Result.new(success?: false, error: "GitHub access denied. Please sign out and sign in again.")
  rescue Octokit::Error => e
    Result.new(success?: false, error: "GitHub API error: #{e.message}")
  end

  private

  def format_repo(repo)
    {
      id: repo.id,
      full_name: repo.full_name,
      name: repo.name,
      owner: repo.owner.login,
      private: repo.private,
      description: repo.description,
      pushed_at: repo.pushed_at,
      html_url: repo.html_url
    }
  end
end

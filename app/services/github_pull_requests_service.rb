require "octokit"

class GithubPullRequestsService
  Result = Struct.new(:success?, :pull_requests, :error, keyword_init: true)

  def initialize(user)
    @user = user
    @client = Octokit::Client.new(access_token: user.github_token, auto_paginate: false)
  end

  def call(repo_full_name, page: 1, per_page: 30)
    prs = @client.pull_requests(
      repo_full_name,
      state: "closed",
      sort: "updated",
      direction: "desc",
      page: page,
      per_page: per_page
    )

    # Filter to only merged PRs
    merged_prs = prs.select { |pr| pr.merged_at.present? }

    Result.new(
      success?: true,
      pull_requests: merged_prs.map { |pr| format_pull_request(pr) }
    )
  rescue Octokit::Unauthorized, Octokit::Forbidden => e
    Result.new(success?: false, error: "GitHub access denied. Please sign out and sign in again.")
  rescue Octokit::NotFound => e
    Result.new(success?: false, error: "Repository not found or you don't have access.")
  rescue Octokit::Error => e
    Result.new(success?: false, error: "GitHub API error: #{e.message}")
  end

  private

  def format_pull_request(pr)
    {
      number: pr.number,
      title: pr.title,
      html_url: pr.html_url,
      merged_at: pr.merged_at,
      user: {
        login: pr.user.login,
        avatar_url: pr.user.avatar_url
      }
    }
  end
end

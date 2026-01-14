class GithubPullRequestsService
  Result = Struct.new(:success?, :pull_requests, :error, keyword_init: true)

  def initialize(project)
    @project = project
  end

  def call(page: 1, per_page: 30)
    client = @project.github_client
    unless client
      return Result.new(success?: false, error: "No GitHub App installation found for this project.")
    end

    prs = client.pull_requests(
      @project.github_repo,
      state: "closed",
      sort: "updated",
      direction: "desc",
      page: page,
      per_page: per_page
    )

    merged_prs = prs.select { |pr| pr.merged_at.present? }

    Result.new(
      success?: true,
      pull_requests: merged_prs.map { |pr| format_pull_request(pr) }
    )
  rescue Octokit::Unauthorized, Octokit::Forbidden => e
    Result.new(success?: false, error: "GitHub access denied. The app may have been uninstalled.")
  rescue Octokit::NotFound => e
    Result.new(success?: false, error: "Repository not found or the app doesn't have access.")
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

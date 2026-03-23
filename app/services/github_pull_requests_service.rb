class GithubPullRequestsService
  Result = Struct.new(:success?, :pull_requests, :error, keyword_init: true)

  def initialize(project)
    @project = project
  end

  def call(page: 1, per_page: 30)
    repo = @project.primary_repository
    adapter = repo&.vcs_adapter || Vcs::Provider.for(repo&.provider || :github)
    client = repo&.vcs_client || @project.github_client
    unless client
      return Result.new(success?: false, error: "No VCS installation found for this project.")
    end

    prs = adapter.pull_requests(
      @project.primary_github_repo,
      client: client,
      state: "closed",
      sort: "updated",
      direction: "desc",
      page: page,
      per_page: per_page
    )

    merged_prs = prs.select { |pr| pr[:merged_at].present? }

    Result.new(success?: true, pull_requests: merged_prs)
  rescue Vcs::AuthenticationError => e
    Result.new(success?: false, error: "Access denied. The app may have been uninstalled.")
  rescue Vcs::NotFoundError => e
    Result.new(success?: false, error: "Repository not found or the app doesn't have access.")
  rescue Vcs::Error => e
    Result.new(success?: false, error: "VCS API error: #{e.message}")
  end
end

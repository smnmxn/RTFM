class GithubCommitsService
  Result = Struct.new(:success?, :commits, :error, keyword_init: true)

  def initialize(project)
    @project = project
  end

  def call(page: 1, per_page: 30)
    repo = @project.primary_repository
    adapter = repo&.vcs_adapter || Vcs::Provider.for(:github)
    client = repo&.vcs_client || @project.github_client
    unless client
      return Result.new(success?: false, error: "No VCS installation found for this project.")
    end

    commits = adapter.commits(
      @project.primary_github_repo,
      client: client,
      page: page,
      per_page: per_page
    )

    Result.new(success?: true, commits: commits)
  rescue Vcs::AuthenticationError => e
    Result.new(success?: false, error: "Access denied. The app may have been uninstalled.")
  rescue Vcs::NotFoundError => e
    Result.new(success?: false, error: "Repository not found or the app doesn't have access.")
  rescue Vcs::Error => e
    Result.new(success?: false, error: "VCS API error: #{e.message}")
  end
end

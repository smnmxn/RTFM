class GithubBranchesService
  Result = Struct.new(:success?, :branches, :default_branch, :error, keyword_init: true)

  def initialize(github_repo:, installation_id:, provider: "github")
    @github_repo = github_repo
    @installation_id = installation_id
    @provider = provider
  end

  def call
    adapter = Vcs::Provider.for(@provider)

    default_branch = adapter.default_branch(@github_repo, installation_id: @installation_id)
    branches = adapter.branches(@github_repo, installation_id: @installation_id)

    Result.new(
      success?: true,
      branches: branches,
      default_branch: default_branch
    )
  rescue Vcs::Error => e
    Rails.logger.error "[GithubBranchesService] Error fetching branches for #{@github_repo}: #{e.class}: #{e.message}"
    Result.new(success?: false, error: "Failed to fetch branches: #{e.message}")
  rescue => e
    Rails.logger.error "[GithubBranchesService] Error fetching branches for #{@github_repo}: #{e.class}: #{e.message}"
    Result.new(success?: false, error: "Failed to fetch branches: #{e.message}")
  end
end

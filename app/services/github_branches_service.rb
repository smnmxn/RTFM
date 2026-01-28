class GithubBranchesService
  Result = Struct.new(:success?, :branches, :default_branch, :error, keyword_init: true)

  def initialize(github_repo:, installation_id:)
    @github_repo = github_repo
    @installation_id = installation_id
  end

  def call
    installation = GithubAppInstallation.find_by(github_installation_id: @installation_id)
    return Result.new(success?: false, error: "Installation not found") unless installation

    client = installation.client
    return Result.new(success?: false, error: "Could not create GitHub client") unless client

    repo_info = client.repository(@github_repo)
    default_branch = repo_info.default_branch

    branches = client.branches(@github_repo, per_page: 100).map(&:name)

    Result.new(
      success?: true,
      branches: branches,
      default_branch: default_branch
    )
  rescue Octokit::Error => e
    Rails.logger.error "[GithubBranchesService] Error fetching branches for #{@github_repo}: #{e.message}"
    Result.new(success?: false, error: "Failed to fetch branches: #{e.message}")
  end
end

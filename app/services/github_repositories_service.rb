class GithubRepositoriesService
  Result = Struct.new(:success?, :repositories, :installations, :error, keyword_init: true)

  def initialize(user)
    @user = user
  end

  def call
    # First-come-claims: assign unclaimed installations to this user
    GithubAppInstallation.active.where(user_id: nil).update_all(user_id: @user.id)

    # Now query only this user's installations
    installations = @user.github_app_installations.active.order(:account_login)

    if installations.empty?
      return Result.new(
        success?: true,
        repositories: [],
        installations: []
      )
    end

    all_repos = []

    installations.each do |installation|
      begin
        response = installation.repositories(per_page: 100)
        repos = response.repositories.map { |r| format_repo(r, installation) }
        all_repos.concat(repos)
      rescue Octokit::NotFound, Octokit::Unauthorized => e
        Rails.logger.warn "[GithubRepositoriesService] Installation #{installation.id} error: #{e.message}"
        # Skip this installation but continue with others
      end
    end

    # Sort by most recently pushed
    all_repos.sort_by! { |r| r[:pushed_at] || Time.at(0) }.reverse!

    Result.new(
      success?: true,
      repositories: all_repos,
      installations: installations
    )
  rescue => e
    Rails.logger.error "[GithubRepositoriesService] Error: #{e.message}"
    Result.new(success?: false, error: "Failed to load repositories: #{e.message}")
  end

  private

  def format_repo(repo, installation)
    {
      id: repo.id,
      full_name: repo.full_name,
      name: repo.name,
      owner: repo.owner.login,
      private: repo.private,
      description: repo.description,
      pushed_at: repo.pushed_at,
      html_url: repo.html_url,
      installation_id: installation.github_installation_id,
      installation_account: installation.account_login
    }
  end
end

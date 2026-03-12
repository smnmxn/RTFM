class GithubRepositoriesService
  Result = Struct.new(:success?, :repositories, :installations, :error, :org_access_limited, keyword_init: true)

  def initialize(user)
    @user = user
  end

  def call
    github_token = user_github_token
    unless github_token
      return Result.new(
        success?: true,
        repositories: [],
        installations: []
      )
    end

    # Find installations the user can access by matching their GitHub
    # username and org memberships against installation account_login
    user_client = Octokit::Client.new(access_token: github_token)
    accessible_accounts = [user_client.user.login]
    org_access_limited = false
    begin
      accessible_accounts += user_client.organizations.map(&:login)
    rescue Octokit::Forbidden
      # Token lacks read:org scope — continue with personal repos only
      org_access_limited = true
    end

    installations = GithubAppInstallation.active
      .where(account_login: accessible_accounts)
      .order(:account_login)

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
      end
    end

    # Sort by most recently pushed (most recent first)
    all_repos.sort_by! { |r|
      pushed_at = r[:pushed_at]
      case pushed_at
      when Time, DateTime then pushed_at.to_time
      when String then Time.parse(pushed_at) rescue Time.at(0)
      else Time.at(0)
      end
    }.reverse!

    Result.new(
      success?: true,
      repositories: all_repos,
      installations: installations,
      org_access_limited: org_access_limited
    )
  rescue => e
    Rails.logger.error "[GithubRepositoriesService] Error: #{e.message}"
    Result.new(success?: false, error: "Failed to load repositories: #{e.message}")
  end

  private

  def user_github_token
    # Try the identity token first, fall back to legacy column
    identity = @user.user_identities.find_by(provider: "github")
    identity&.token || @user.github_token
  end

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

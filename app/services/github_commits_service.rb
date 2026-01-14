class GithubCommitsService
  Result = Struct.new(:success?, :commits, :error, keyword_init: true)

  def initialize(project)
    @project = project
  end

  def call(page: 1, per_page: 30)
    client = @project.github_client
    unless client
      return Result.new(success?: false, error: "No GitHub App installation found for this project.")
    end

    commits = client.commits(
      @project.github_repo,
      page: page,
      per_page: per_page
    )

    Result.new(
      success?: true,
      commits: commits.map { |commit| format_commit(commit) }
    )
  rescue Octokit::Unauthorized, Octokit::Forbidden => e
    Result.new(success?: false, error: "GitHub access denied. The app may have been uninstalled.")
  rescue Octokit::NotFound => e
    Result.new(success?: false, error: "Repository not found or the app doesn't have access.")
  rescue Octokit::Error => e
    Result.new(success?: false, error: "GitHub API error: #{e.message}")
  end

  private

  def format_commit(commit)
    {
      sha: commit.sha,
      short_sha: commit.sha[0..6],
      message: commit.commit.message,
      title: commit.commit.message.split("\n").first.truncate(100),
      html_url: commit.html_url,
      committed_at: commit.commit.committer.date,
      author: {
        login: commit.author&.login || commit.commit.author.name,
        avatar_url: commit.author&.avatar_url || gravatar_url(commit.commit.author.email)
      }
    }
  end

  def gravatar_url(email)
    hash = Digest::MD5.hexdigest(email.to_s.downcase.strip)
    "https://www.gravatar.com/avatar/#{hash}?d=identicon"
  end
end

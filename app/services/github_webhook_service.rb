require "octokit"

class GithubWebhookService
  Result = Struct.new(:success?, :webhook_id, :error, keyword_init: true)

  WEBHOOK_EVENTS = [ "pull_request" ].freeze

  def initialize(user)
    @user = user
    @client = Octokit::Client.new(access_token: user.github_token)
  end

  def create(repo_full_name:, webhook_secret:, webhook_url:)
    config = {
      url: webhook_url,
      content_type: "json",
      secret: webhook_secret
    }

    hook = @client.create_hook(
      repo_full_name,
      "web",
      config,
      events: WEBHOOK_EVENTS,
      active: true
    )

    Result.new(success?: true, webhook_id: hook.id)
  rescue Octokit::UnprocessableEntity => e
    if e.message.include?("Hook already exists")
      Result.new(success?: false, error: :webhook_exists)
    else
      Result.new(success?: false, error: e.message)
    end
  rescue Octokit::NotFound
    Result.new(success?: false, error: :repo_not_found)
  rescue Octokit::Forbidden
    Result.new(success?: false, error: :no_admin_access)
  rescue Octokit::Error => e
    Result.new(success?: false, error: e.message)
  end

  def delete(repo_full_name:, webhook_id:)
    @client.remove_hook(repo_full_name, webhook_id)
    Result.new(success?: true)
  rescue Octokit::Error => e
    Result.new(success?: false, error: e.message)
  end
end

class BitbucketRepositoriesService
  Result = Struct.new(:success?, :repositories, :connections, :error, keyword_init: true)

  def initialize(user)
    @user = user
  end

  def call
    connections = BitbucketConnection.active.for_user(@user)

    unless connections.any?
      return Result.new(
        success?: true,
        repositories: [],
        connections: []
      )
    end

    all_repos = []

    connections.each do |connection|
      begin
        adapter = Vcs::Provider.for(:bitbucket)
        repos = adapter.list_repositories(connection)
        all_repos.concat(repos)
      rescue Vcs::AuthenticationError, Vcs::NotFoundError => e
        Rails.logger.warn "[BitbucketRepositoriesService] Connection #{connection.id} error: #{e.message}"
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
      connections: connections
    )
  rescue => e
    Rails.logger.error "[BitbucketRepositoriesService] Error: #{e.message}"
    Result.new(success?: false, error: "Failed to load Bitbucket repositories: #{e.message}")
  end
end

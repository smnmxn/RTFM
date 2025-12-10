class ProjectsController < ApplicationController
  def new
    @repositories = []
  end

  def show
    @project = current_user.projects.find(params[:id])
  end

  def pull_requests
    @project = current_user.projects.find(params[:id])
    service = GithubPullRequestsService.new(current_user)
    page = (params[:page] || 1).to_i
    result = service.call(@project.github_repo, page: page)

    if result.success?
      @pull_requests = result.pull_requests
      @page = page
      @has_more = result.pull_requests.size == 30

      render partial: "projects/pull_request_list"
    else
      render partial: "projects/pull_request_error", locals: { error: result.error }
    end
  end

  def analyze
    @project = current_user.projects.find(params[:id])

    if @project.analysis_status == "running"
      redirect_to project_path(@project), alert: "Analysis is already in progress."
      return
    end

    @project.update!(analysis_status: "pending")
    AnalyzeCodebaseJob.perform_later(@project.id)

    redirect_to project_path(@project), notice: "Codebase analysis started. This may take a few minutes."
  end

  def repositories
    service = GithubRepositoriesService.new(current_user)
    page = (params[:page] || 1).to_i
    result = service.call(page: page)

    Rails.logger.info "[ProjectsController#repositories] Success: #{result.success?}, Repos: #{result.repositories&.size || 0}, Error: #{result.error}"

    if result.success?
      @repositories = result.repositories
      @page = page
      @has_more = result.repositories.size == 30
      @connected_repos = current_user.projects.pluck(:github_repo)

      render partial: "projects/repository_list"
    else
      render partial: "projects/repository_error", locals: { error: result.error }
    end
  end

  def create
    repo_full_name = params[:github_repo].presence
    repo_name = repo_full_name&.split("/")&.last

    # Build project (generates webhook_secret via before_create callback)
    @project = current_user.projects.build(
      name: repo_name&.titleize&.tr("-", " "),
      github_repo: repo_full_name
    )

    unless @project.valid?
      redirect_to new_project_path, alert: @project.errors.full_messages.join(", ")
      return
    end

    # Create webhook on GitHub
    webhook_service = GithubWebhookService.new(current_user)
    webhook_url = if ENV["HOST_URL"].present?
      "#{ENV['HOST_URL']}/webhooks/github"
    else
      webhooks_github_url(protocol: "https")
    end

    result = webhook_service.create(
      repo_full_name: repo_full_name,
      webhook_secret: @project.webhook_secret,
      webhook_url: webhook_url
    )

    Rails.logger.info "[ProjectsController#create] Webhook URL: #{webhook_url}"
    Rails.logger.info "[ProjectsController#create] Webhook result: success=#{result.success?}, error=#{result.error.inspect}"

    if result.success?
      @project.github_webhook_id = result.webhook_id
      @project.save!
      redirect_to dashboard_path, notice: "Project '#{@project.name}' connected successfully!"
    else
      handle_webhook_error(result.error, repo_full_name)
    end
  end

  def destroy
    @project = current_user.projects.find(params[:id])

    # Remove webhook from GitHub if we have its ID
    if @project.github_webhook_id.present?
      webhook_service = GithubWebhookService.new(current_user)
      webhook_service.delete(
        repo_full_name: @project.github_repo,
        webhook_id: @project.github_webhook_id
      )
    end

    @project.destroy
    redirect_to dashboard_path, notice: "Project '#{@project.name}' disconnected."
  end

  private

  def handle_webhook_error(error, repo_full_name)
    case error
    when :webhook_exists
      # Webhook exists - could be from previous setup. Create project anyway.
      @project.save!
      redirect_to dashboard_path,
        notice: "Project connected! Note: A webhook already existed on this repository."
    when :no_admin_access
      redirect_to new_project_path,
        alert: "You need admin access to #{repo_full_name} to create webhooks."
    when :repo_not_found
      redirect_to new_project_path,
        alert: "Repository not found. It may have been deleted or made private."
    else
      redirect_to new_project_path,
        alert: "Failed to create webhook: #{error}"
    end
  end
end

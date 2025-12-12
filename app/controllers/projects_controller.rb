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

  def analyze_pull_request
    @project = current_user.projects.find(params[:id])
    pr_number = params[:pr_number].to_i

    # Check if analysis is already running for this PR
    existing_update = @project.updates.find_by(pull_request_number: pr_number)
    if existing_update&.analysis_status == "running"
      redirect_to project_path(@project), alert: "Analysis is already in progress for PR ##{pr_number}."
      return
    end

    # Get PR details from form params (passed from the view)
    pr_title = params[:pr_title].presence || "PR ##{pr_number}"
    pr_url = params[:pr_url].presence || "https://github.com/#{@project.github_repo}/pull/#{pr_number}"

    # Enqueue the analysis job
    AnalyzePullRequestJob.perform_later(
      project_id: @project.id,
      pull_request_number: pr_number,
      pull_request_url: pr_url,
      pull_request_title: pr_title,
      pull_request_body: params[:pr_body].to_s
    )

    redirect_to project_path(@project), notice: "Analysis started for PR ##{pr_number}. This may take a few minutes."
  end

  def generate_recommendations
    @project = current_user.projects.find(params[:id])

    unless @project.analysis_status == "completed"
      redirect_to project_path(@project), alert: "Please run codebase analysis first."
      return
    end

    GenerateProjectRecommendationsJob.perform_later(project_id: @project.id)

    redirect_to project_path(@project), notice: "Generating article recommendations. This may take a few minutes."
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

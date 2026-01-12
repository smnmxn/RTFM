class ProjectsController < ApplicationController
  before_action :set_project, except: [ :new, :create, :repositories ]

  def new
    @repositories = []
  end

  def show
    @pending_recommendations = @project.recommendations.pending
      .includes(:section)
      .order(created_at: :asc)

    @inbox_articles = @project.articles
      .where(review_status: :unreviewed)
      .where(generation_status: [ :generation_running, :generation_completed ])
      .includes(:section)
      .order(created_at: :asc)

    # Select first completed article (higher priority), or first recommendation
    @selected_article = @inbox_articles.where(generation_status: :generation_completed).first
    @selected_recommendation = @selected_article.nil? ? @pending_recommendations.first : nil

    @inbox_empty = @pending_recommendations.empty? && @inbox_articles.empty?

    # Articles tab data
    @articles_sections = @project.sections.visible.ordered
    @uncategorized_articles_count = @project.articles.for_help_centre.where(section: nil).count
    @total_published_articles = @project.articles.for_help_centre.count
  end

  def select_article
    @article = @project.articles.find(params[:article_id])

    render partial: "projects/article_editor", locals: { article: @article }
  end

  def approve_article
    @article = @project.articles.find(params[:article_id])
    article_created_at = @article.created_at
    @article.approve!
    @article.publish!

    load_inbox_items
    @next_item = find_next_item_after_article(article_created_at)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project) }
    end
  end

  def reject_article
    @article = @project.articles.find(params[:article_id])
    article_created_at = @article.created_at
    @article.reject!

    load_inbox_items
    @next_item = find_next_item_after_article(article_created_at)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project) }
    end
  end

  def undo_reject_article
    @article = @project.articles.find(params[:article_id])
    @article.update!(review_status: :unreviewed, reviewed_at: nil)

    load_inbox_items

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project) }
    end
  end

  # Recommendation inbox actions
  def select_recommendation
    @recommendation = @project.recommendations.find(params[:recommendation_id])

    render partial: "projects/recommendation_editor", locals: { recommendation: @recommendation }
  end

  def accept_recommendation
    @recommendation = @project.recommendations.find(params[:recommendation_id])
    recommendation_created_at = @recommendation.created_at

    # Create article with generating status
    @article = @project.articles.create!(
      recommendation: @recommendation,
      section: @recommendation.section,
      title: @recommendation.title,
      content: "Generating article...",
      generation_status: :generation_running,
      review_status: :unreviewed
    )

    # Mark recommendation as generated
    @recommendation.update!(status: :generated)

    # Enqueue article generation job
    GenerateArticleJob.perform_later(article_id: @article.id)

    load_inbox_items
    @next_item = find_next_item_after_recommendation(recommendation_created_at)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project) }
    end
  end

  def reject_recommendation
    @recommendation = @project.recommendations.find(params[:recommendation_id])
    recommendation_created_at = @recommendation.created_at
    @recommendation.update!(status: :rejected, rejected_at: Time.current)

    load_inbox_items
    @next_item = find_next_item_after_recommendation(recommendation_created_at)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project) }
    end
  end

  # Articles tab actions
  def select_articles_section
    @section_id = params[:section_id]

    @articles = if @section_id == "uncategorized"
      @project.articles.for_help_centre.where(section: nil).ordered
    elsif @section_id.present?
      @project.sections.find(@section_id).articles.for_help_centre.ordered
    else
      []
    end

    @selected_article = @articles.first

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@project, anchor: "articles") }
    end
  end

  def select_articles_article
    @article = @project.articles.for_help_centre.find(params[:article_id])
    @sections = @project.sections.visible.ordered

    render partial: "projects/articles_editor", locals: {
      article: @article,
      project: @project,
      sections: @sections
    }
  end

  def pull_requests
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

  def code_history
    @view_type = params[:view].presence || "prs"
    page = (params[:page] || 1).to_i

    if @view_type == "commits"
      service = GithubCommitsService.new(current_user)
      result = service.call(@project.github_repo, page: page)

      if result.success?
        @commits = result.commits
        @updates_by_commit = @project.updates
          .from_commits
          .where(commit_sha: @commits.map { |c| c[:sha] })
          .index_by(&:commit_sha)
        @page = page
        @has_more = result.commits.size == 30

        render partial: "projects/code_history_commits", locals: { project: @project }
      else
        render partial: "projects/pull_request_error", locals: { error: result.error }
      end
    else
      service = GithubPullRequestsService.new(current_user)
      result = service.call(@project.github_repo, page: page)

      if result.success?
        @pull_requests = result.pull_requests
        @updates_by_pr = @project.updates
          .from_pull_requests
          .where(pull_request_number: @pull_requests.map { |pr| pr[:number] })
          .index_by(&:pull_request_number)
        @page = page
        @has_more = result.pull_requests.size == 30

        render partial: "projects/code_history_timeline", locals: { project: @project }
      else
        render partial: "projects/pull_request_error", locals: { error: result.error }
      end
    end
  end

  def analyze_commit
    commit_sha = params[:commit_sha]

    # Check if analysis is already running for this commit
    existing_update = @project.updates.find_by(commit_sha: commit_sha, source_type: :commit)
    if existing_update&.analysis_status == "running"
      redirect_to project_path(@project, anchor: "code-history"), alert: "Analysis is already in progress for commit #{commit_sha[0..6]}."
      return
    end

    # Get commit details from form params
    commit_title = params[:commit_title].presence || "Commit #{commit_sha[0..6]}"
    commit_url = params[:commit_url].presence || "https://github.com/#{@project.github_repo}/commit/#{commit_sha}"

    AnalyzeCommitJob.perform_later(
      project_id: @project.id,
      commit_sha: commit_sha,
      commit_url: commit_url,
      commit_title: commit_title,
      commit_message: params[:commit_message].to_s
    )

    redirect_to project_path(@project, anchor: "code-history"), notice: "Analysis started for commit #{commit_sha[0..6]}. This may take a few minutes."
  end

  def analyze
    if @project.analysis_status == "running"
      redirect_to project_path(@project), alert: "Analysis is already in progress."
      return
    end

    @project.update!(analysis_status: "pending")
    AnalyzeCodebaseJob.perform_later(@project.id)

    redirect_to project_path(@project), notice: "Codebase analysis started. This may take a few minutes."
  end

  def analyze_pull_request
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

      # Pass through onboarding project if in wizard
      @onboarding_project = current_user.projects.find_by(id: params[:onboarding_project_id]) if params[:onboarding_project_id].present?

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

  def set_project
    @project = current_user.projects.find(params[:id])
  end

  def load_inbox_items
    @pending_recommendations = @project.recommendations.pending
      .includes(:section)
      .order(created_at: :asc)

    @inbox_articles = @project.articles
      .where(review_status: :unreviewed)
      .where(generation_status: [ :generation_running, :generation_completed ])
      .includes(:section)
      .order(created_at: :asc)

    @inbox_empty = @pending_recommendations.empty? && @inbox_articles.empty?
  end

  # Find the next inbox item after an article (by created_at order)
  # Articles appear above recommendations, so after an article we check:
  # 1. Next completed article (created after this one)
  # 2. First recommendation (if no more articles)
  def find_next_item_after_article(article_created_at)
    next_article = @inbox_articles
      .where(generation_status: :generation_completed)
      .where("created_at > ?", article_created_at)
      .first

    return next_article if next_article

    # No more articles after this one, get first recommendation
    @pending_recommendations.first
  end

  # Find the next inbox item after a recommendation (by created_at order)
  # Recommendations appear below articles, so after a recommendation we only check:
  # 1. Next recommendation (created after this one)
  def find_next_item_after_recommendation(recommendation_created_at)
    @pending_recommendations
      .where("created_at > ?", recommendation_created_at)
      .first
  end

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

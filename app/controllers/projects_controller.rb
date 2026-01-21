class ProjectsController < ApplicationController
  before_action :set_project, except: [ :index, :new, :create, :repositories ]

  def index
    @projects = current_user.projects.order(updated_at: :desc)
  end

  def new
    # All new projects should go through onboarding
    redirect_to new_onboarding_project_path
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

    # Use URL param for selection persistence, fallback to first item
    @selected_article = nil
    @selected_recommendation = nil

    if params[:selected].present?
      type, id = params[:selected].split("_", 2)
      if type == "article" && id.present?
        @selected_article = @inbox_articles.find_by(id: id)
      elsif type == "recommendation" && id.present?
        @selected_recommendation = @pending_recommendations.find_by(id: id)
      end
    end

    # Fallback to default selection if param invalid or not provided
    @selected_article ||= @inbox_articles.where(generation_status: :generation_completed).first
    @selected_recommendation ||= @selected_article.nil? ? @pending_recommendations.first : nil

    @inbox_empty = @pending_recommendations.empty? && @inbox_articles.empty?

    # Articles tab data
    @articles_sections = @project.sections.visible.ordered
    @uncategorized_articles_count = @project.articles.for_editor.where(section: nil).count
    @total_published_articles = @project.articles.for_editor.count

    # Article preselection (from ?article=:id param, used by help centre Edit link)
    if params[:article].present?
      @preselected_article = @project.articles.for_editor.find_by(id: params[:article])
      @preselected_section = @preselected_article&.section
      @active_tab = "articles" if @preselected_article
    end

    @active_tab ||= "inbox"
  end

  def inbox_articles
    @inbox_articles = @project.articles
      .where(review_status: :unreviewed)
      .where(generation_status: [:generation_running, :generation_completed])
      .includes(:section)
      .order(created_at: :asc)

    @pending_recommendations = @project.recommendations.pending
      .includes(:section)
      .order(created_at: :asc)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def select_article
    @article = @project.articles.find(params[:article_id])

    if turbo_frame_request?
      render partial: "projects/article_editor", locals: { article: @article }
    else
      redirect_to project_path(@project, selected: params[:selected])
    end
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

    if turbo_frame_request?
      render partial: "projects/recommendation_editor", locals: { recommendation: @recommendation }
    else
      redirect_to project_path(@project, selected: "recommendation_#{@recommendation.id}")
    end
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
      @project.articles.for_editor.where(section: nil).ordered
    elsif @section_id.present?
      @project.sections.find(@section_id).articles.for_editor.ordered
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
    @article = @project.articles.for_editor.find(params[:article_id])
    @sections = @project.sections.visible.ordered

    if turbo_frame_request?
      render partial: "projects/articles_editor", locals: {
        article: @article,
        project: @project,
        sections: @sections
      }
    else
      redirect_to project_path(@project, article: @article.id)
    end
  end

  def pull_requests
    service = GithubPullRequestsService.new(@project)
    page = (params[:page] || 1).to_i
    result = service.call(page: page)

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
      service = GithubCommitsService.new(@project)
      result = service.call(page: page)

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
      service = GithubPullRequestsService.new(@project)
      result = service.call(page: page)

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
    result = GithubRepositoriesService.new(current_user).call

    Rails.logger.info "[ProjectsController#repositories] Success: #{result.success?}, Repos: #{result.repositories&.size || 0}, Installations: #{result.installations&.size || 0}"

    if result.success?
      @repositories = result.repositories
      @installations = result.installations
      @connected_repos = current_user.projects.pluck(:github_repo)

      # Pass through onboarding project if in wizard
      @onboarding_project = current_user.projects.find_by(slug: params[:onboarding_project_slug]) if params[:onboarding_project_slug].present?

      render partial: "projects/repository_list"
    else
      render partial: "projects/repository_error", locals: { error: result.error }
    end
  end

  def create
    # All new projects should go through onboarding
    redirect_to new_onboarding_project_path
  end

  def start_over
    # Clear all generated content
    @project.articles.destroy_all
    @project.recommendations.destroy_all
    @project.sections.destroy_all

    # Reset status and enter onboarding
    @project.update!(
      analysis_status: nil,
      sections_generation_status: nil,
      onboarding_step: "analyze"
    )

    redirect_to analyze_onboarding_project_path(@project)
  end

  # Branding settings
  def update_branding
    # Handle subdomain separately (it's a direct column, not part of branding JSON)
    subdomain_value = params[:project]&.delete(:subdomain)

    # Merge new values into existing branding (similar to save_context pattern)
    current_branding = @project.branding || {}
    new_branding = current_branding.merge(branding_params.to_h.stringify_keys)

    update_attrs = { branding: new_branding }
    update_attrs[:subdomain] = subdomain_value.presence if params[:project]&.key?(:subdomain) || subdomain_value.present?

    if @project.update(update_attrs)
      @project.reload
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "branding_form",
            partial: "projects/branding_form",
            locals: { project: @project, saved: true }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings"), notice: "Branding updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "branding_form",
            partial: "projects/branding_form",
            locals: { project: @project, saved: false }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings"), alert: "Failed to update branding." }
      end
    end
  end

  def upload_logo
    if params[:logo].present? && @project.logo.attach(params[:logo])
      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true, url: url_for(@project.logo) } }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.json { render json: { success: false, errors: @project.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def remove_logo
    @project.logo.purge
    respond_to do |format|
      format.turbo_stream
      format.json { render json: { success: true } }
    end
  end

  # AI settings
  def update_ai_settings
    current_ai_settings = @project.ai_settings || {}
    new_ai_settings = current_ai_settings.merge(ai_settings_params.to_h.stringify_keys)

    if @project.update(ai_settings: new_ai_settings)
      @project.reload
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "ai_settings_form",
            partial: "projects/ai_settings_form",
            locals: { project: @project, saved: true }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings"), notice: "AI settings updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "ai_settings_form",
            partial: "projects/ai_settings_form",
            locals: { project: @project, saved: false }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings"), alert: "Failed to update AI settings." }
      end
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project '#{@project.name}' disconnected."
  end

  private

  def set_project
    @project = current_user.projects.find_by(slug: params[:slug])
    unless @project
      redirect_to projects_path, alert: "Project not found."
    end
  end

  def branding_params
    params.require(:project).permit(:primary_color, :accent_color, :title_text_color, :help_centre_title, :help_centre_tagline)
  end

  def ai_settings_params
    params.require(:project).permit(:claude_model)
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
  # 2. First recommendation (if no more articles after)
  # 3. First completed article (wrap around)
  def find_next_item_after_article(article_created_at)
    next_article = @inbox_articles
      .where(generation_status: :generation_completed)
      .where("created_at > ?", article_created_at)
      .first

    return next_article if next_article

    # No more articles after this one, try first recommendation
    return @pending_recommendations.first if @pending_recommendations.any?

    # No recommendations, wrap to first completed article
    @inbox_articles.where(generation_status: :generation_completed).first
  end

  # Find the next inbox item after a recommendation (by created_at order)
  # Recommendations appear below articles, so after a recommendation we only check:
  # 1. Next recommendation (created after this one)
  def find_next_item_after_recommendation(recommendation_created_at)
    @pending_recommendations
      .where("created_at > ?", recommendation_created_at)
      .first
  end

end

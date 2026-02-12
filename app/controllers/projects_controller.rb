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
      .where(generation_status: [ :generation_pending, :generation_running, :generation_completed, :generation_failed ])
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
    # Don't override an explicitly selected recommendation with an article fallback
    if @selected_recommendation.nil?
      @selected_article ||= @inbox_articles.where(generation_status: :generation_completed).first
      @selected_recommendation ||= @selected_article.nil? ? @pending_recommendations.first : nil
    end

    @inbox_empty = @pending_recommendations.empty? && @inbox_articles.empty?

    # Articles tab data
    @articles_sections = @project.sections.visible.ordered
    @uncategorized_articles_count = @project.articles.for_folder_tree.where(section: nil).count
    @total_published_articles = @project.articles.for_folder_tree.count

    # Article preselection (from ?article=:id param, used by help centre Edit link)
    if params[:article].present?
      @preselected_article = @project.articles.for_folder_tree.find_by(id: params[:article])
      @preselected_section = @preselected_article&.section
      @active_tab = "articles" if @preselected_article
    end

    # Section preselection (from ?section=:id param, used after creating a section)
    if params[:section].present? && @preselected_section.nil?
      @preselected_section = @project.sections.find_by(id: params[:section])
      @active_tab = "articles" if @preselected_section
    end

    @active_tab ||= "inbox"
  end

  def inbox_articles
    @inbox_articles = @project.articles
      .where(review_status: :unreviewed)
      .where(generation_status: [ :generation_pending, :generation_running, :generation_completed, :generation_failed ])
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
    if params[:section_id].present?
      section = @project.sections.find(params[:section_id])
      @article.update!(section: section)
    end
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
  def select_articles_article
    @article = @project.articles.for_folder_tree.find(params[:article_id])
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
    page = (params[:page] || 1).to_i

    # Fetch both commits and PRs
    commits_service = GithubCommitsService.new(@project)
    prs_service = GithubPullRequestsService.new(@project)

    commits_result = commits_service.call(page: page)
    prs_result = prs_service.call(page: page)

    unless commits_result.success? && prs_result.success?
      error = commits_result.error || prs_result.error
      render partial: "projects/pull_request_error", locals: { error: error }
      return
    end

    # Build unified timeline items
    @timeline_items = []

    # Add commits to timeline
    commits_result.commits.each do |commit|
      @timeline_items << {
        type: :commit,
        date: commit[:committed_at],
        sha: commit[:sha],
        short_sha: commit[:short_sha],
        title: commit[:title],
        message: commit[:message],
        url: commit[:html_url],
        author: commit[:author]
      }
    end

    # Add PRs to timeline
    prs_result.pull_requests.each do |pr|
      @timeline_items << {
        type: :pull_request,
        date: pr[:merged_at],
        pr_number: pr[:number],
        merge_commit_sha: pr[:merge_commit_sha],
        title: pr[:title],
        url: pr[:html_url],
        author: pr[:user]
      }
    end

    # Deduplicate: when a PR's merge commit SHA matches a commit, remove the commit
    # (the PR is more informative — it has title, number, etc.)
    pr_merge_shas = @timeline_items
      .select { |i| i[:type] == :pull_request && i[:merge_commit_sha].present? }
      .map { |i| i[:merge_commit_sha] }
      .to_set

    @timeline_items.reject! { |i| i[:type] == :commit && pr_merge_shas.include?(i[:sha]) }

    # Sort by date descending
    @timeline_items.sort_by! { |item| item[:date] }.reverse!

    # Index existing updates by commit SHA and PR number
    commit_shas = @timeline_items.select { |i| i[:type] == :commit }.map { |i| i[:sha] }
    pr_numbers = @timeline_items.select { |i| i[:type] == :pull_request }.map { |i| i[:pr_number] }

    @updates_by_commit = @project.updates
      .from_commits
      .where(commit_sha: commit_shas)
      .index_by(&:commit_sha)

    @updates_by_pr = @project.updates
      .from_pull_requests
      .where(pull_request_number: pr_numbers)
      .index_by(&:pull_request_number)

    # Add update reference to each timeline item
    @timeline_items.each do |item|
      item[:update] = if item[:type] == :commit
        @updates_by_commit[item[:sha]]
      else
        @updates_by_pr[item[:pr_number]]
      end
    end

    # Cutoff: items at or before the baseline can't be analyzed
    # Find the baseline item (could be a commit SHA or a PR's merge commit SHA)
    baseline_sha = @project.analysis_commit_sha
    if baseline_sha.present?
      baseline_item = @timeline_items.find do |i|
        (i[:type] == :commit && i[:sha] == baseline_sha) ||
          (i[:type] == :pull_request && i[:merge_commit_sha] == baseline_sha)
      end
      @analysis_cutoff_date = baseline_item&.dig(:date)
    end

    @page = page
    @has_more = commits_result.commits.size == 30 || prs_result.pull_requests.size == 30
    @latest_recommendation_shown = ActiveModel::Type::Boolean.new.cast(params[:latest_recommendation_shown]) || false

    render partial: "projects/code_history_unified", locals: { project: @project }
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

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.action(:replace, "code-history-timeline",
          partial: "projects/code_history_timeline_reload",
          locals: { project: @project })
      end
      format.html { redirect_to project_path(@project, anchor: "code-history"), notice: "Analysis started for commit #{commit_sha[0..6]}." }
    end
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
      pull_request_body: params[:pr_body].to_s,
      merge_commit_sha: params[:merge_commit_sha].presence
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.action(:replace, "code-history-timeline",
          partial: "projects/code_history_timeline_reload",
          locals: { project: @project })
      end
      format.html { redirect_to project_path(@project, anchor: "code-history"), notice: "Analysis started for PR ##{pr_number}." }
    end
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

      # Pass through onboarding project if in wizard
      @onboarding_project = current_user.projects.find_by(slug: params[:onboarding_project_slug]) if params[:onboarding_project_slug].present?

      # Split connected repos: this project vs other projects
      if @onboarding_project
        @connected_to_this_project = @onboarding_project.project_repositories.pluck(:github_repo)
        @connected_to_other_projects = current_user.projects
          .where.not(id: @onboarding_project.id)
          .joins(:project_repositories)
          .pluck("project_repositories.github_repo")
      else
        @connected_to_this_project = []
        @connected_to_other_projects = []
      end

      # For backwards compatibility, @connected_repos includes all connected repos
      @connected_repos = @connected_to_this_project + @connected_to_other_projects

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

  def update_strategy
    current_ai_settings = @project.ai_settings || {}
    new_ai_settings = current_ai_settings.merge("update_strategy" => params.dig(:project, :update_strategy))

    if @project.update(ai_settings: new_ai_settings)
      @project.reload
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "update_strategy_form",
            partial: "projects/update_strategy_form",
            locals: { project: @project, saved: true }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings"), notice: "Update strategy saved." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "update_strategy_form",
            partial: "projects/update_strategy_form",
            locals: { project: @project, saved: false }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings"), alert: "Failed to update strategy." }
      end
    end
  end

  def test_toast
    Turbo::StreamsChannel.broadcast_append_to(
      [ @project, :notifications ],
      target: "toast-container",
      partial: "shared/toast",
      locals: {
        message: "This is a test notification",
        type: params[:toast_type] || "success",
        action_url: project_path(@project),
        action_label: "View",
        persistent: params[:toast_type] == "error"
      }
    )

    head :ok
  end

  def preview_notification_email
    event_type = params[:event_type]
    sample = build_sample_notifications(event_type)

    @preview_html = NotificationMailer.digest(
      user: current_user,
      project: @project,
      notifications: sample
    ).html_part&.body&.decoded || NotificationMailer.digest(
      user: current_user,
      project: @project,
      notifications: sample
    ).body.decoded

    render layout: false
  end

  def update_notification_preferences
    prefs = current_user.notification_preferences || {}
    prefs["email_notifications_enabled"] = params[:email_notifications_enabled] == "1"
    prefs["email_events"] ||= {}

    User::DEFAULT_NOTIFICATION_PREFERENCES["email_events"].each_key do |event|
      prefs["email_events"][event] = params.dig(:email_events, event) == "1"
    end

    current_user.update!(notification_preferences: prefs)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "notification-preferences-form",
          partial: "projects/notification_preferences_form",
          locals: { project: @project, user: current_user, saved: true }
        )
      end
      format.html { redirect_to project_path(@project, anchor: "settings/notifications"), notice: "Notification preferences saved." }
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project '#{@project.name}' disconnected."
  end

  # Repository management actions

  def add_repository
    repo_full_name = params[:github_repo]
    installation_id = params[:installation_id]

    installation = GithubAppInstallation.find_by(github_installation_id: installation_id)
    unless installation
      redirect_to project_path(@project, anchor: "settings"), alert: "GitHub App installation not found."
      return
    end

    # Check if repo is already connected to another project
    existing_repo = ProjectRepository.find_by(github_repo: repo_full_name)
    if existing_repo && existing_repo.project_id != @project.id
      redirect_to project_path(@project, anchor: "settings"), alert: "This repository is already connected to another project."
      return
    end

    @project.project_repositories.create!(
      github_repo: repo_full_name,
      github_installation_id: installation.github_installation_id,
      is_primary: @project.project_repositories.empty?
    )

    redirect_to project_path(@project, anchor: "settings"), notice: "Repository #{repo_full_name} added."
  end

  def remove_repository
    repo = @project.project_repositories.find(params[:repository_id])

    if @project.project_repositories.count == 1
      redirect_to project_path(@project, anchor: "settings"), alert: "Cannot remove the only repository."
      return
    end

    # Reassign primary if removing the primary repo
    if repo.is_primary?
      @project.project_repositories.where.not(id: repo.id).first&.update!(is_primary: true)
    end

    repo.destroy

    redirect_to project_path(@project, anchor: "settings"), notice: "Repository removed."
  end

  def set_primary_repository
    repo = @project.project_repositories.find(params[:repository_id])

    @project.project_repositories.update_all(is_primary: false)
    repo.update!(is_primary: true)

    # Also update legacy github_repo field
    @project.update!(github_repo: repo.github_repo)

    redirect_to project_path(@project, anchor: "settings"), notice: "Primary repository updated."
  end

  # Custom domain management

  def update_custom_domain
    custom_domain = params.dig(:project, :custom_domain).to_s.strip

    if custom_domain.blank?
      redirect_to project_path(@project, anchor: "settings/custom-domain"), alert: "Please enter a custom domain."
      return
    end

    if @project.update(custom_domain: custom_domain)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "custom_domain_form",
            partial: "projects/custom_domain_form",
            locals: { project: @project, saved: true }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings/custom-domain"), notice: "Custom domain added. Follow the DNS instructions to complete setup." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "custom_domain_form",
            partial: "projects/custom_domain_form",
            locals: { project: @project, saved: false }
          )
        end
        format.html { redirect_to project_path(@project, anchor: "settings/custom-domain"), alert: @project.errors.full_messages.join(", ") }
      end
    end
  end

  def verify_custom_domain
    unless @project.custom_domain.present? && @project.custom_domain_cloudflare_id.present?
      redirect_to project_path(@project, anchor: "settings/custom-domain"), alert: "No custom domain configured."
      return
    end

    # Trigger immediate status check
    CheckCustomDomainStatusJob.perform_later(project_id: @project.id, retry_count: 0)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "custom_domain_form",
          partial: "projects/custom_domain_form",
          locals: { project: @project, saved: false, checking: true }
        )
      end
      format.html { redirect_to project_path(@project, anchor: "settings/custom-domain"), notice: "Checking domain status..." }
    end
  end

  def remove_custom_domain
    old_cloudflare_id = @project.custom_domain_cloudflare_id

    @project.update!(
      custom_domain: nil,
      custom_domain_status: nil,
      custom_domain_cloudflare_id: nil,
      custom_domain_ssl_status: nil,
      custom_domain_verified_at: nil
    )

    # Clean up from Cloudflare
    if old_cloudflare_id.present?
      RemoveCustomDomainJob.perform_later(cloudflare_id: old_cloudflare_id)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "custom_domain_form",
          partial: "projects/custom_domain_form",
          locals: { project: @project, saved: true }
        )
      end
      format.html { redirect_to project_path(@project, anchor: "settings/custom-domain"), notice: "Custom domain removed." }
    end
  end

  # Article update check actions (Maintenance)

  def create_article_update_check
    # Get target commit from params or fetch latest
    target_commit = params[:target_commit].presence || fetch_latest_commit_sha

    unless target_commit.present?
      redirect_to project_path(@project, anchor: "settings/maintenance"), alert: "Could not determine target commit."
      return
    end

    check = @project.article_update_checks.create!(
      target_commit_sha: target_commit,
      base_commit_sha: @project.analysis_commit_sha
    )

    CheckArticleUpdatesJob.perform_later(check_id: check.id)

    redirect_to project_path(@project, anchor: "settings/maintenance"), notice: "Checking for article updates..."
  end

  def article_update_check
    @check = @project.article_update_checks.find(params[:check_id])

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "update_check_#{@check.id}",
          partial: "projects/article_update_check",
          locals: { check: @check }
        )
      end
      format.html { redirect_to project_path(@project, anchor: "settings/maintenance") }
    end
  end

  private

  SAMPLE_NOTIFICATIONS = {
    "analysis_complete"         => { message: "We've finished analysing your codebase",      status: "success", metadata: { "repo_count" => 2 } },
    "sections_suggested"        => { message: "We've suggested sections for your docs",      status: "success", metadata: { "section_count" => 5, "section_names" => [ "Getting Started", "Authentication", "API Reference", "Configuration", "Troubleshooting" ] } },
    "recommendations_generated" => { message: "We've got 12 article ideas for you",          status: "success", metadata: { "recommendation_count" => 12, "section_count" => 4 } },
    "article_generated"         => { message: "Your article is ready: Getting Started Guide", status: "success", metadata: { "article_title" => "Getting Started Guide", "article_id" => 1 } },
    "pr_analyzed"               => { message: "We've reviewed code changes from PR #42",                       status: "success", metadata: { "pr_number" => 42, "pr_title" => "Add dark mode support", "article_titles" => [ "Update Authentication Docs", "Add Dark Mode Configuration Guide" ] } },
    "commit_analyzed"           => { message: "We've reviewed code changes from commit a1b2c3d",               status: "success", metadata: { "commit_sha" => "a1b2c3d4e5f6", "commit_title" => "Fix authentication flow", "article_titles" => [ "Update Login Troubleshooting Guide" ] } }
  }.freeze

  def build_sample_notifications(event_type)
    events = if event_type.present? && SAMPLE_NOTIFICATIONS.key?(event_type)
      [ [ event_type, SAMPLE_NOTIFICATIONS[event_type] ] ]
    else
      SAMPLE_NOTIFICATIONS.to_a
    end

    events.map do |type, data|
      action_url = case type
      when "sections_suggested"
        "/onboarding/projects/#{@project.slug}/sections"
      else
        "/projects/#{@project.slug}"
      end

      PendingNotification.new(
        user: current_user,
        project: @project,
        event_type: type,
        status: data[:status],
        message: data[:message],
        action_url: action_url,
        metadata: data[:metadata]
      )
    end
  end

  def set_project
    @project = current_user.projects.find_by(slug: params[:slug])
    unless @project
      redirect_to projects_path, alert: "Project not found."
    end
  end

  def branding_params
    params.require(:project).permit(:primary_color, :accent_color, :title_text_color, :help_centre_title, :help_centre_tagline, :support_email, :support_phone, :dark_mode)
  end

  def ai_settings_params
    params.require(:project).permit(:claude_model, :claude_max_turns, :update_strategy)
  end

  def load_inbox_items
    @pending_recommendations = @project.recommendations.pending
      .includes(:section)
      .order(created_at: :asc)

    @inbox_articles = @project.articles
      .where(review_status: :unreviewed)
      .where(generation_status: [ :generation_pending, :generation_running, :generation_completed, :generation_failed ])
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

  def fetch_latest_commit_sha
    service = GithubCommitsService.new(@project)
    result = service.call(page: 1, per_page: 1)
    return nil unless result.success? && result.commits.present?
    result.commits.first[:sha]
  rescue => e
    Rails.logger.error "[ProjectsController] Failed to fetch latest commit: #{e.message}"
    nil
  end
end

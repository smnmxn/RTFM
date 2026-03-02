class AccountAnalyticsService
  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date
  end

  def call
    projects = Project.includes(:user).index_by(&:id)
    project_ids = projects.keys

    # Batch queries scoped to period
    events_in_period = ProductEvent.between(@start_date, @end_date)

    total_events_by_project = events_in_period.group(:project_id).count
    last_active_by_project = events_in_period.group(:project_id).maximum(:created_at)

    # All-time queries for structural data
    articles_by_project = Article.group(:project_id).count
    published_by_project = Article.where(status: "published").group(:project_id).count
    custom_domains = Project.where.not(custom_domain: nil).where(custom_domain_status: "active")
      .pluck(:id, :custom_domain).to_h

    # TTFV per project
    ttfv_by_project = compute_ttfv_by_project

    # Approval rate per project (period-scoped)
    approved_by_project = events_in_period.for_event("article.approved").group(:project_id).count
    rejected_by_project = events_in_period.for_event("article.rejected").group(:project_id).count

    # Edit rate per project (period-scoped)
    edit_rates_by_project = compute_edit_rates_by_project(events_in_period)

    # Build project summaries
    results = projects.filter_map do |pid, project|
      user = project.user
      next unless user

      approved = approved_by_project[pid] || 0
      rejected = rejected_by_project[pid] || 0
      review_total = approved + rejected

      last_active = last_active_by_project[pid]

      onboarding_step = project.onboarding_step
      onboarding_status = if onboarding_step.nil? || onboarding_step == "complete"
        "complete"
      else
        onboarding_step
      end

      {
        project: project,
        user: user,
        onboarding_status: onboarding_status,
        articles_count: articles_by_project[pid] || 0,
        articles_published: published_by_project[pid] || 0,
        custom_domain: custom_domains[pid],
        ttfv_minutes: ttfv_by_project[pid],
        approval_rate: review_total > 0 ? (approved.to_f / review_total * 100).round(1) : nil,
        edit_rate: edit_rates_by_project[pid],
        last_active_at: last_active,
        total_events: total_events_by_project[pid] || 0
      }
    end

    results.sort_by { |a| a[:last_active_at] || Time.at(0) }.reverse
  end

  def project_detail(project)
    events_in_period = ProductEvent.between(@start_date, @end_date)
    project_events = events_in_period.for_project(project.id)

    # Articles
    articles_count = project.articles.count
    published_count = Article.where(project: project, status: "published").count

    # TTFV for this project
    ttfv = compute_ttfv_for_project(project.id)

    # Approval/rejection in period
    approved = project_events.for_event("article.approved").count
    rejected = project_events.for_event("article.rejected").count
    review_total = approved + rejected

    # Edit rate in period
    published_article_ids = project_events.for_event("article.published")
      .pluck(:properties).filter_map { |p| p&.dig("article_id") }.uniq

    edited_ids = if published_article_ids.any?
      published_set = published_article_ids.map(&:to_s).to_set
      ProductEvent.for_event("article.edited").where(project_id: project.id)
        .pluck(:properties).filter_map { |p| p&.dig("article_id") }.uniq
        .select { |id| published_set.include?(id.to_s) }
    else
      []
    end

    edit_rate = published_article_ids.any? ? (edited_ids.size.to_f / published_article_ids.size * 100).round(1) : nil

    # Article lifecycle counts
    generated_count = project_events.for_event("article.generated").count
    approved_count = approved
    rejected_count = rejected
    published_event_count = project_events.for_event("article.published").count

    # Custom domain status
    has_active_domain = project.custom_domain_active?

    # Recent events
    recent_events = ProductEvent.where(project_id: project.id).order(created_at: :desc).limit(50)

    # Last active
    last_active = ProductEvent.where(project_id: project.id).maximum(:created_at)

    {
      project: project,
      user: project.user,
      articles_count: articles_count,
      articles_published: published_count,
      ttfv_minutes: ttfv,
      approval_rate: review_total > 0 ? (approved.to_f / review_total * 100).round(1) : nil,
      articles_reviewed: review_total,
      edit_rate: edit_rate,
      has_active_domain: has_active_domain,
      custom_domain: project.custom_domain_active? ? project.custom_domain : nil,
      last_active_at: last_active,
      recent_events: recent_events,
      total_events_in_period: project_events.count,
      article_lifecycle: {
        generated: generated_count,
        approved: approved_count,
        rejected: rejected_count,
        published: published_event_count
      }
    }
  end

  private

  def compute_ttfv_by_project
    created_events = ProductEvent.for_event("project.created").pluck(:project_id, :created_at)
    generated_events = ProductEvent.for_event("article.generated").order(:created_at)
      .pluck(:project_id, :created_at)

    first_generated = {}
    generated_events.each { |pid, ts| first_generated[pid] ||= ts }

    ttfv_by_project = {}
    created_events.each do |pid, created_at|
      gen_at = first_generated[pid]
      next unless gen_at
      minutes = ((gen_at - created_at) / 60.0).round(1)
      ttfv_by_project[pid] = minutes
    end

    ttfv_by_project
  end

  def compute_ttfv_for_project(project_id)
    created_event = ProductEvent.for_event("project.created").where(project_id: project_id)
      .order(:created_at).first
    return nil unless created_event

    generated_event = ProductEvent.for_event("article.generated")
      .where(project_id: project_id).order(:created_at).first
    return nil unless generated_event

    ((generated_event.created_at - created_event.created_at) / 60.0).round(1)
  end

  def compute_edit_rates_by_project(events_in_period)
    # Get published article_ids per project
    published_data = events_in_period.for_event("article.published")
      .pluck(:project_id, :properties)

    published_by_project = {}
    published_data.each do |pid, props|
      aid = props&.dig("article_id")
      next unless aid
      (published_by_project[pid] ||= Set.new) << aid.to_s
    end

    return {} if published_by_project.empty?

    # Get all edited article_ids for relevant projects
    all_edited = ProductEvent.for_event("article.edited")
      .where(project_id: published_by_project.keys)
      .pluck(:project_id, :properties)

    edited_by_project = {}
    all_edited.each do |pid, props|
      aid = props&.dig("article_id")
      next unless aid
      (edited_by_project[pid] ||= Set.new) << aid.to_s
    end

    result = {}
    published_by_project.each do |pid, pub_set|
      edited_set = edited_by_project[pid] || Set.new
      edited_published = pub_set & edited_set
      result[pid] = (edited_published.size.to_f / pub_set.size * 100).round(1)
    end
    result
  end
end

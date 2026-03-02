class ProductAnalyticsSummaryService
  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @events = ProductEvent.between(@start_date, @end_date)
  end

  def call
    {
      summary: summary,
      fundraise_metrics: fundraise_metrics,
      onboarding_funnel: onboarding_funnel,
      article_lifecycle: article_lifecycle,
      recommendations: recommendations_stats,
      custom_domain: custom_domain_stats,
      daily_activity: daily_activity,
      active_users: active_users
    }
  end

  private

  def summary
    {
      total_events: @events.count,
      active_users: @events.distinct.count(:user_id),
      active_projects: @events.where.not(project_id: nil).distinct.count(:project_id),
      articles_published: @events.for_event("article.published").count,
      custom_domains_verified: @events.for_event("settings.custom_domain_verified").count
    }
  end

  def fundraise_metrics
    # 1. Design partners live: projects that completed onboarding AND have published articles (all time)
    completed_project_ids = ProductEvent.for_event("project.onboarding_completed").distinct.pluck(:project_id)
    projects_with_published = ProductEvent.for_event("article.published")
      .where(project_id: completed_project_ids)
      .distinct.pluck(:project_id)
    design_partners_live = projects_with_published.size

    # 2. Time-to-first-value: median minutes from project.created to first article.generated per project
    created_events = ProductEvent.for_event("project.created").pluck(:project_id, :created_at)
    generated_events = ProductEvent.for_event("article.generated")
      .order(:created_at)
      .pluck(:project_id, :created_at)

    # Group first generation time by project
    first_generated_by_project = {}
    generated_events.each do |pid, ts|
      first_generated_by_project[pid] ||= ts
    end

    ttfv_minutes = created_events.filter_map do |pid, created_at|
      first_gen = first_generated_by_project[pid]
      next unless first_gen
      ((first_gen - created_at) / 60.0).round(1)
    end.sort

    median_ttfv = if ttfv_minutes.any?
      mid = ttfv_minutes.size / 2
      ttfv_minutes.size.odd? ? ttfv_minutes[mid] : ((ttfv_minutes[mid - 1] + ttfv_minutes[mid]) / 2.0).round(1)
    end

    # 3. Approval rate: approved / (approved + rejected) from inbox review
    approved = @events.for_event("article.approved").count
    rejected = @events.for_event("article.rejected").count
    review_total = approved + rejected
    approval_rate = review_total > 0 ? (approved.to_f / review_total * 100).round(1) : nil

    # 4. Edit rate: % of published articles that were edited before publishing
    published_article_ids = @events.for_event("article.published")
      .pluck(:properties).filter_map { |p| p&.dig("article_id") }.uniq

    edited_published_ids = if published_article_ids.any?
      published_set = published_article_ids.map(&:to_s).to_set
      ProductEvent.for_event("article.edited")
        .pluck(:properties).filter_map { |p| p&.dig("article_id") }.uniq
        .select { |id| published_set.include?(id.to_s) }
    else
      []
    end

    edit_rate = published_article_ids.any? ? (edited_published_ids.size.to_f / published_article_ids.size * 100).round(1) : nil

    # 5. Onboarding drop-off at repository step (proxy for security objection)
    created_count = @events.for_event("project.created").count
    step_events = @events.for_event("project.onboarding_step_completed").pluck(:project_id, :properties)
    connected_repo_count = step_events
      .select { |_, props| props&.dig("step") == "repository" }
      .map(&:first).uniq.size
    repo_drop_off_rate = created_count > 0 ? ((1 - connected_repo_count.to_f / created_count) * 100).round(1) : nil

    # 6. Help centre page views (from AnalyticsEvent — proxy for support deflection)
    help_centre_views = AnalyticsEvent.between(@start_date, @end_date).page_views.count
    help_centre_visitors = AnalyticsEvent.between(@start_date, @end_date).page_views.distinct.count(:visitor_id)

    {
      design_partners_live: design_partners_live,
      median_ttfv_minutes: median_ttfv,
      approval_rate: approval_rate,
      articles_reviewed: review_total,
      edit_rate: edit_rate,
      articles_published: published_article_ids.size,
      repo_drop_off_rate: repo_drop_off_rate,
      onboarding_started: created_count,
      repo_connected: connected_repo_count,
      help_centre_views: help_centre_views,
      help_centre_visitors: help_centre_visitors
    }
  end

  def onboarding_funnel
    steps = %w[repository setup analyze sections]
    step_counts = {}

    # Count unique projects that completed each step (filter in Ruby for json column compatibility)
    step_events = @events.for_event("project.onboarding_step_completed").pluck(:project_id, :properties)
    steps.each do |step|
      step_counts[step] = step_events
        .select { |_, props| props&.dig("step") == step }
        .map(&:first)
        .uniq
        .size
    end

    # Also count projects created and onboarding completed
    step_counts["created"] = @events.for_event("project.created").count
    step_counts["completed"] = @events.for_event("project.onboarding_completed").distinct.count(:project_id)

    # Build funnel with conversion rates
    ordered = ["created"] + steps + ["completed"]
    funnel_steps = ordered.map { |s| { step: s, count: step_counts[s] || 0 } }

    rates = funnel_steps.each_cons(2).map do |prev, curr|
      {
        from: prev[:step],
        to: curr[:step],
        rate: prev[:count] > 0 ? (curr[:count].to_f / prev[:count] * 100).round(1) : 0
      }
    end

    { steps: funnel_steps, rates: rates }
  end

  def article_lifecycle
    generated = @events.for_event("article.generated").count
    approved = @events.for_event("article.approved").count
    rejected = @events.for_event("article.rejected").count
    published = @events.for_event("article.published").count

    # "Published without edit" metric
    # Get article_ids from published events in this period
    published_article_ids = @events.for_event("article.published")
      .pluck(:properties)
      .filter_map { |p| p&.dig("article_id") }
      .uniq

    # Get article_ids that have ANY edit events (all time, not just this period)
    edited_article_ids = if published_article_ids.any?
      published_set = published_article_ids.map(&:to_s).to_set
      ProductEvent.for_event("article.edited")
        .pluck(:properties)
        .filter_map { |p| p&.dig("article_id") }
        .uniq
        .select { |id| published_set.include?(id.to_s) }
    else
      []
    end

    unedited_published = published_article_ids - edited_article_ids
    no_edit_pct = published_article_ids.any? ? (unedited_published.size.to_f / published_article_ids.size * 100).round(1) : 0

    {
      generated: generated,
      approved: approved,
      rejected: rejected,
      published: published,
      published_without_edit: unedited_published.size,
      published_without_edit_pct: no_edit_pct
    }
  end

  def recommendations_stats
    accepted = @events.for_event("recommendation.accepted").count
    rejected = @events.for_event("recommendation.rejected").count
    total = accepted + rejected
    acceptance_rate = total > 0 ? (accepted.to_f / total * 100).round(1) : 0

    { accepted: accepted, rejected: rejected, acceptance_rate: acceptance_rate }
  end

  def custom_domain_stats
    added = @events.for_event("settings.custom_domain_added").count
    verified = @events.for_event("settings.custom_domain_verified").count
    removed = @events.for_event("settings.custom_domain_removed").count
    current_active = Project.where.not(custom_domain: nil).where(custom_domain_status: "active").count

    { added: added, verified: verified, removed: removed, current_active: current_active }
  end

  def daily_activity
    events_by_date = @events.group("date(created_at)").count
    users_by_date = @events.group("date(created_at)").distinct.count(:user_id)

    (@start_date.to_date..@end_date.to_date).map do |date|
      key = date.to_s
      { date: key, events: events_by_date[key] || 0, users: users_by_date[key] || 0 }
    end
  end

  def active_users
    now = Time.current
    dau = ProductEvent.where("created_at >= ?", now - 1.day).distinct.count(:user_id)
    wau = ProductEvent.where("created_at >= ?", now - 7.days).distinct.count(:user_id)
    mau = ProductEvent.where("created_at >= ?", now - 30.days).distinct.count(:user_id)

    { dau: dau, wau: wau, mau: mau }
  end
end

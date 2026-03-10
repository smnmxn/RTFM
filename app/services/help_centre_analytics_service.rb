class HelpCentreAnalyticsService
  def initialize(start_date, end_date, period = "30d")
    @start_date = start_date
    @end_date = end_date
    @period = period
  end

  def call
    events = AnalyticsEvent.help_centre.between(@start_date, @end_date).page_views
    project_ids = events.distinct.pluck(:project_id)
    return [] if project_ids.empty?

    projects = Project.includes(:user).where(id: project_ids).index_by(&:id)

    views_by_project = events.group(:project_id).count
    unique_by_project = events.group(:project_id).count("DISTINCT visitor_id")

    # Top page per project
    top_pages = events.group(:project_id, :page_path).count
    top_page_by_project = {}
    top_pages.each do |(pid, path), count|
      if top_page_by_project[pid].nil? || count > top_page_by_project[pid][:count]
        top_page_by_project[pid] = { path: path, count: count }
      end
    end

    # Mobile percentage
    mobile_by_project = events.where(device_type: "mobile").group(:project_id).count

    # Published articles
    published_by_project = Article.where(project_id: project_ids, status: "published").group(:project_id).count

    # Custom domains
    custom_domains = Project.where(id: project_ids).where.not(custom_domain: nil)
      .where(custom_domain_status: "active").pluck(:id, :custom_domain).to_h

    results = project_ids.filter_map do |pid|
      project = projects[pid]
      next unless project

      total = views_by_project[pid] || 0
      unique = unique_by_project[pid] || 0

      {
        project: project,
        user: project.user,
        total_page_views: total,
        unique_visitors: unique,
        avg_pages_per_visitor: unique > 0 ? (total.to_f / unique).round(1) : 0,
        top_page: top_page_by_project.dig(pid, :path),
        mobile_pct: total > 0 ? ((mobile_by_project[pid] || 0).to_f / total * 100).round(1) : 0,
        articles_published: published_by_project[pid] || 0,
        custom_domain: custom_domains[pid]
      }
    end

    results.sort_by { |r| -r[:total_page_views] }
  end

  def project_detail(project)
    events = AnalyticsEvent.for_project(project.id).between(@start_date, @end_date)
    page_views_scope = events.page_views
    page_views = page_views_scope.to_a

    total = page_views.size
    unique = page_views.map(&:visitor_id).uniq.size

    # Daily/hourly views (same pattern as AnalyticsSummaryService)
    daily_views = if @period == "24h"
      views_by_hour = page_views.group_by { |e| e.created_at.beginning_of_hour }
      uniques_by_hour = views_by_hour.transform_values { |evts| evts.map(&:visitor_id).uniq.count }

      current = @start_date.beginning_of_hour
      result = []
      while current <= @end_date
        evts = views_by_hour[current] || []
        result << { date: current.strftime("%H:%M"), views: evts.count, uniques: uniques_by_hour[current] || 0 }
        current += 1.hour
      end
      result
    else
      views_by_date = page_views.group_by { |e| e.created_at.to_date }
      uniques_by_date = views_by_date.transform_values { |evts| evts.map(&:visitor_id).uniq.count }

      (@start_date.to_date..@end_date.to_date).map do |date|
        evts = views_by_date[date] || []
        { date: date.strftime("%b %d"), views: evts.count, uniques: uniques_by_date[date] || 0 }
      end
    end

    # Top pages
    top_pages = page_views_scope.group(:page_path)
      .order(Arel.sql("count(*) DESC"))
      .limit(20)
      .count
      .map { |path, count| { path: path, views: count } }

    # Top referrers
    top_referrers = page_views_scope.where.not(referrer_host: [nil, ""])
      .group(:referrer_host)
      .order(Arel.sql("count(*) DESC"))
      .limit(10)
      .count
      .map { |host, count| { host: host, views: count } }

    # Device breakdown
    device_breakdown = page_views_scope.where.not(device_type: [nil, ""])
      .group(:device_type).count

    # Browser breakdown
    browser_breakdown = page_views_scope.where.not(browser_family: [nil, ""])
      .group(:browser_family).count

    {
      total_page_views: total,
      unique_visitors: unique,
      avg_pages_per_visitor: unique > 0 ? (total.to_f / unique).round(1) : 0,
      articles_published: Article.where(project: project, status: "published").count,
      daily_views: daily_views,
      top_pages: top_pages,
      top_referrers: top_referrers,
      device_breakdown: device_breakdown,
      browser_breakdown: browser_breakdown
    }
  end
end

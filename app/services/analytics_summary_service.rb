class AnalyticsSummaryService
  def initialize(start_date, end_date)
    @start_date = start_date
    @end_date = end_date
    @events = AnalyticsEvent.between(@start_date, @end_date)
  end

  def call
    {
      summary: summary,
      daily_views: daily_views,
      top_pages: top_pages,
      top_referrers: top_referrers,
      utm_breakdown: utm_breakdown,
      device_breakdown: device_breakdown,
      browser_breakdown: browser_breakdown,
      engagement: engagement,
      funnel: funnel
    }
  end

  private

  def summary
    page_views = @events.page_views
    {
      total_page_views: page_views.count,
      unique_visitors: page_views.distinct.count(:visitor_id),
      total_engagement: @events.engagement.count
    }
  end

  def daily_views
    page_views = @events.page_views

    views_by_date = page_views
      .group("date(created_at)")
      .count

    uniques_by_date = page_views
      .group("date(created_at)")
      .distinct
      .count(:visitor_id)

    (@start_date.to_date..@end_date.to_date).map do |date|
      key = date.to_s
      {
        date: key,
        views: views_by_date[key] || 0,
        uniques: uniques_by_date[key] || 0
      }
    end
  end

  def top_pages
    @events.page_views
      .group(:page_path)
      .order(Arel.sql("count(*) DESC"))
      .limit(20)
      .count
      .map { |path, count| { path: path, views: count } }
  end

  def top_referrers
    @events.page_views
      .where.not(referrer_host: [ nil, "" ])
      .group(:referrer_host)
      .order(Arel.sql("count(*) DESC"))
      .limit(10)
      .count
      .map { |host, count| { host: host, views: count } }
  end

  def utm_breakdown
    @events.page_views
      .where.not(utm_source: [ nil, "" ])
      .group(:utm_source)
      .order(Arel.sql("count(*) DESC"))
      .limit(10)
      .count
      .map { |source, count| { source: source, views: count } }
  end

  def device_breakdown
    @events.page_views
      .where.not(device_type: [ nil, "" ])
      .group(:device_type)
      .count
  end

  def browser_breakdown
    @events.page_views
      .where.not(browser_family: [ nil, "" ])
      .group(:browser_family)
      .count
  end

  def engagement
    video_plays = @events.where(event_type: "video_play").count
    video_progress_events = @events.where(event_type: "video_progress")

    progress_values = video_progress_events.pluck(:event_data).filter_map do |data|
      data.is_a?(Hash) ? data["progress"] : (JSON.parse(data.to_s)["progress"] rescue nil)
    end
    avg_progress = progress_values.any? ? (progress_values.sum.to_f / progress_values.size).round(1) : 0

    waitlist_submits = @events.where(event_type: "waitlist_submit").count

    cta_clicks = @events.where(event_type: "cta_click")
    cta_detail = cta_clicks.pluck(:event_data).each_with_object(Hash.new(0)) do |data, hash|
      cta = data.is_a?(Hash) ? data["cta"] : (JSON.parse(data.to_s)["cta"] rescue "unknown")
      hash[cta || "unknown"] += 1
    end

    {
      video_plays: video_plays,
      avg_video_progress: avg_progress,
      waitlist_submits: waitlist_submits,
      cta_clicks: cta_clicks.count,
      cta_detail: cta_detail
    }
  end

  def funnel
    total_page_views = @events.page_views.distinct.count(:visitor_id)
    return { steps: [], rates: [] } if total_page_views == 0

    video_play_visitors = @events.where(event_type: "video_play").distinct.count(:visitor_id)
    video_50_visitors = @events.where(event_type: "video_progress")
      .select { |e|
        data = e.event_data
        progress = data.is_a?(Hash) ? data["progress"] : (JSON.parse(data.to_s)["progress"] rescue 0)
        progress.to_i >= 50
      }
      .map(&:visitor_id).uniq.count
    waitlist_visitors = @events.where(event_type: "waitlist_submit").distinct.count(:visitor_id)

    steps = [
      { name: "Page View", count: total_page_views },
      { name: "Video Play", count: video_play_visitors },
      { name: "Video 50%", count: video_50_visitors },
      { name: "Waitlist Signup", count: waitlist_visitors }
    ]

    rates = steps.each_cons(2).map do |prev, curr|
      {
        from: prev[:name],
        to: curr[:name],
        rate: prev[:count] > 0 ? (curr[:count].to_f / prev[:count] * 100).round(1) : 0
      }
    end

    { steps: steps, rates: rates }
  end
end

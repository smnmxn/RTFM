class AnalyticsSummaryService
  def initialize(start_date, end_date, period = "30d")
    @start_date = start_date
    @end_date = end_date
    @period = period
    @events = AnalyticsEvent.between(@start_date, @end_date)
  end

  def call
    {
      summary: summary,
      visitor_breakdown: visitor_breakdown,
      daily_views: daily_views,
      top_pages: top_pages,
      top_referrers: top_referrers,
      utm_breakdown: utm_breakdown,
      utm_content_breakdown: utm_content_breakdown,
      prospect_tracking: prospect_tracking,
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

  def visitor_breakdown
    visitor_ids = @events.distinct.pluck(:visitor_id)
    visitors = Visitor.where(visitor_id: visitor_ids)

    {
      total_visitors: visitors.count,
      new_visitors: visitors.where(total_page_views: 1).count,
      returning_visitors: visitors.where("total_page_views > 1").count,
      identified_visitors: visitors.identified.count,
      anonymous_visitors: visitors.anonymous.count,
      converted_visitors: visitors.where.not(user_id: nil).count,
      avg_pages_per_visitor: visitors.average(:total_page_views).to_f.round(1)
    }
  end

  def daily_views
    page_views = @events.page_views.to_a

    # For 24h view, group by hour; otherwise group by day
    if @period == "24h"
      # Hourly breakdown - group in Ruby for reliability
      views_by_hour = page_views.group_by { |e| e.created_at.beginning_of_hour }
      uniques_by_hour = page_views.group_by { |e| e.created_at.beginning_of_hour }
        .transform_values { |events| events.map(&:visitor_id).uniq.count }

      # Generate array of hours from start to end
      current = @start_date.beginning_of_hour
      result = []
      while current <= @end_date
        events = views_by_hour[current] || []
        result << {
          date: current.strftime("%H:%M"),
          full_date: current,
          views: events.count,
          uniques: uniques_by_hour[current] || 0
        }
        current += 1.hour
      end
      result
    else
      # Daily breakdown - group in Ruby for reliability
      views_by_date = page_views.group_by { |e| e.created_at.to_date }
      uniques_by_date = page_views.group_by { |e| e.created_at.to_date }
        .transform_values { |events| events.map(&:visitor_id).uniq.count }

      (@start_date.to_date..@end_date.to_date).map do |date|
        events = views_by_date[date] || []
        {
          date: date.strftime("%b %d"),
          full_date: date,
          views: events.count,
          uniques: uniques_by_date[date] || 0
        }
      end
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
    visitor_ids = @events.page_views.distinct.pluck(:visitor_id)
    Visitor.where(visitor_id: visitor_ids)
           .where.not(utm_source: [ nil, "" ])
           .group(:utm_source)
           .order(Arel.sql("count(*) DESC"))
           .limit(10)
           .count
           .map { |source, count| { source: source, visitors: count } }
  end

  def utm_content_breakdown
    visitor_ids = @events.page_views.distinct.pluck(:visitor_id)
    Visitor.where(visitor_id: visitor_ids)
           .where.not(utm_content: [ nil, "" ])
           .group(:utm_content)
           .order(Arel.sql("count(*) DESC"))
           .limit(10)
           .count
           .map { |content, count| { content: content, visitors: count } }
  end

  def prospect_tracking
    prospect_events = @events.where.not(utm_content: [ nil, "" ])
    return [] if prospect_events.empty?

    # Group all events by utm_content
    prospects_data = prospect_events.group_by(&:utm_content)

    prospects_data.map do |utm_content, events|
      page_views = events.select { |e| e.event_type == "page_view" }
      video_plays = events.count { |e| e.event_type == "video_play" }
      waitlist_submits = events.count { |e| e.event_type == "waitlist_submit" }
      cta_clicks = events.count { |e| e.event_type == "cta_click" }

      {
        prospect: utm_content,
        page_views: page_views.size,
        unique_visitors: page_views.map(&:visitor_id).uniq.size,
        video_plays: video_plays,
        waitlist_submits: waitlist_submits,
        cta_clicks: cta_clicks,
        first_seen: events.map(&:created_at).min,
        last_active: events.map(&:created_at).max
      }
    end.sort_by { |p| p[:last_active] }.reverse
  end

  def device_breakdown
    visitor_ids = @events.page_views.distinct.pluck(:visitor_id)
    Visitor.where(visitor_id: visitor_ids)
           .where.not(device_type: [ nil, "" ])
           .group(:device_type)
           .count
  end

  def browser_breakdown
    visitor_ids = @events.page_views.distinct.pluck(:visitor_id)
    Visitor.where(visitor_id: visitor_ids)
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

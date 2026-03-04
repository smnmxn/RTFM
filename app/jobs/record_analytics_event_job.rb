class RecordAnalyticsEventJob < ApplicationJob
  queue_as :low
  discard_on StandardError

  def perform(visitor_id:, event_type:, page_path:, ip_address: nil, referrer_url: nil, user_agent: nil,
              utm_source: nil, utm_medium: nil, utm_campaign: nil, utm_term: nil, utm_content: nil,
              event_data: nil)
    device_type, browser_family, os_family = parse_user_agent(user_agent)
    referrer_host = extract_host(referrer_url)

    # Find or create visitor record
    visitor = Visitor.find_or_create_by!(visitor_id: visitor_id) do |v|
      # First-touch attribution
      v.utm_source = utm_source
      v.utm_medium = utm_medium
      v.utm_campaign = utm_campaign
      v.utm_term = utm_term
      v.utm_content = utm_content
      v.initial_referrer_url = referrer_url
      v.initial_referrer_host = referrer_host
      v.initial_landing_page = page_path
      v.first_seen_at = Time.current
      v.last_seen_at = Time.current
      v.last_ip_address = ip_address
      v.last_user_agent = user_agent
      v.device_type = device_type
      v.browser_family = browser_family
      v.os_family = os_family
    end

    # Create analytics event (simplified - no visitor metadata)
    AnalyticsEvent.create!(
      visitor_id: visitor_id,
      event_type: event_type,
      event_data: event_data,
      page_path: page_path,
      referrer_url: referrer_url,
      referrer_host: referrer_host,
      utm_source: utm_source,
      utm_medium: utm_medium,
      utm_campaign: utm_campaign,
      utm_term: utm_term,
      utm_content: utm_content,
      device_type: device_type,
      browser_family: browser_family,
      os_family: os_family
    )

    # Update visitor activity counters and last-seen metadata
    visitor.record_activity!(
      event_type: event_type,
      ip_address: ip_address,
      user_agent: user_agent,
      device_type: device_type,
      browser_family: browser_family,
      os_family: os_family
    )
  rescue ActiveRecord::RecordNotUnique
    # Race condition - retry
    retry
  end

  private

  def parse_user_agent(ua)
    ua = ua.to_s
    return [ "unknown", "Other", "Other" ] if ua.blank?

    device_type = if ua.match?(/Mobi|Android.*Mobile|iPhone|iPod/i)
      "mobile"
    elsif ua.match?(/iPad|Android(?!.*Mobile)|Tablet/i)
      "tablet"
    else
      "desktop"
    end

    browser_family = if ua.match?(/Edg\//i)
      "Edge"
    elsif ua.match?(/Chrome/i) && !ua.match?(/Edg\//i)
      "Chrome"
    elsif ua.match?(/Firefox/i)
      "Firefox"
    elsif ua.match?(/Safari/i) && !ua.match?(/Chrome/i)
      "Safari"
    else
      "Other"
    end

    os_family = if ua.match?(/iPhone|iPad|iPod/i)
      "iOS"
    elsif ua.match?(/Windows/i)
      "Windows"
    elsif ua.match?(/Macintosh|Mac OS/i)
      "macOS"
    elsif ua.match?(/Android/i)
      "Android"
    elsif ua.match?(/Linux/i)
      "Linux"
    else
      "Other"
    end

    [ device_type, browser_family, os_family ]
  end

  def extract_host(url)
    return nil if url.blank?
    URI.parse(url).host
  rescue URI::InvalidURIError
    nil
  end
end

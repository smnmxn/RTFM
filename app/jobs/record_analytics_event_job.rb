class RecordAnalyticsEventJob < ApplicationJob
  queue_as :low
  discard_on StandardError

  def perform(visitor_id:, event_type:, page_path:, referrer_url: nil, user_agent: nil,
              utm_source: nil, utm_medium: nil, utm_campaign: nil, utm_term: nil, utm_content: nil,
              event_data: nil)
    device_type, browser_family, os_family = parse_user_agent(user_agent)
    referrer_host = extract_host(referrer_url)

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

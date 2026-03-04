module Trackable
  extend ActiveSupport::Concern

  # Comprehensive bot detection patterns
  BOT_PATTERNS = /
    bot|crawl|spider|slurp|scrape|
    mediapartners|facebookexternalhit|bingpreview|
    lighthouse|pingdom|uptimerobot|statuscake|
    headlesschrome|phantomjs|selenium|webdriver|
    curl|wget|python|java|go-http|axios|
    postman|insomnia|httpie|
    ahrefsbot|semrushbot|mj12bot|dotbot|
    baidu|yandex|duckduckgo|
    monitoring|check_http|nagios|
    prerender|archive\.org|
    ia_archiver|wayback
  /ix

  included do
    after_action :track_page_view, if: :should_track?
  end

  private

  def ensure_visitor_id
    return cookies[:_sp_vid] if cookies[:_sp_vid].present?

    vid = SecureRandom.uuid
    cookies[:_sp_vid] = {
      value: vid,
      expires: 1.year.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
    vid
  end

  def should_track?
    return false if bot_request?
    return false unless response.successful? || response.redirect?
    true
  end

  def bot_request?
    ua = request.user_agent.to_s
    return true if ua.blank?
    return true if ua.match?(BOT_PATTERNS)
    return true if suspicious_user_agent?(ua)
    false
  end

  def suspicious_user_agent?(ua)
    # Catch generic/suspicious patterns that bots often use
    return true if ua.length < 10  # Too short to be real browser
    return true if ua.match?(/^(Mozilla\/5\.0)?$/)  # Just "Mozilla/5.0" with nothing else

    # Must have at least one known browser identifier
    has_browser = ua.match?(/Chrome|Safari|Firefox|Edge|Opera|MSIE|Trident/i)
    # Must have OS/platform identifier
    has_platform = ua.match?(/Windows|Macintosh|Linux|Android|iPhone|iPad/i)
    # Must have AppleWebKit, Gecko, or similar rendering engine
    has_engine = ua.match?(/AppleWebKit|Gecko|Trident|Presto/i)

    # Real browsers have all three components
    return true unless has_browser && (has_platform || has_engine)

    false
  end

  def track_page_view
    visitor_id = ensure_visitor_id

    RecordAnalyticsEventJob.perform_later(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: request.path,
      ip_address: request.remote_ip,
      referrer_url: request.referer,
      user_agent: request.user_agent,
      utm_source: params[:utm_source],
      utm_medium: params[:utm_medium],
      utm_campaign: params[:utm_campaign],
      utm_term: params[:utm_term],
      utm_content: params[:utm_content]
    )
  end
end

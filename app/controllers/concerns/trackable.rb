module Trackable
  extend ActiveSupport::Concern

  BOT_PATTERNS = /bot|crawl|spider|slurp|mediapartners|facebookexternalhit|bingpreview|lighthouse|pingdom|uptimerobot|headlesschrome|phantomjs/i

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
    ua.blank? || ua.match?(BOT_PATTERNS)
  end

  def track_page_view
    visitor_id = ensure_visitor_id

    RecordAnalyticsEventJob.perform_later(
      visitor_id: visitor_id,
      event_type: "page_view",
      page_path: request.path,
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

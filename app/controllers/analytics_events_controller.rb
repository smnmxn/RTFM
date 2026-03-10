class AnalyticsEventsController < ApplicationController
  skip_before_action :require_authentication
  skip_forgery_protection

  # Simple in-memory rate limiting
  RATE_LIMIT = 60 # max events per visitor per minute
  @@request_counts = {}
  @@last_cleanup = Time.current

  def create
    visitor_id = cookies[:_sp_vid]
    head :no_content and return if visitor_id.blank?
    head :no_content and return if rate_limited?(visitor_id)

    event_type = params[:event_type]
    head :no_content and return unless AnalyticsEvent::EVENT_TYPES.include?(event_type)

    RecordAnalyticsEventJob.perform_later(
      visitor_id: visitor_id,
      event_type: event_type,
      event_data: params[:event_data]&.to_unsafe_h,
      page_path: params[:page_path] || request.referer&.then { |r| URI.parse(r).path rescue "/" } || "/",
      referrer_url: request.referer,
      user_agent: request.user_agent,
      project_id: params[:project_id]
    )

    head :no_content
  end

  private

  def rate_limited?(visitor_id)
    cleanup_if_needed

    key = "#{visitor_id}:#{Time.current.to_i / 60}"
    @@request_counts[key] = (@@request_counts[key] || 0) + 1
    @@request_counts[key] > RATE_LIMIT
  end

  def cleanup_if_needed
    return if Time.current - @@last_cleanup < 120

    @@request_counts.clear
    @@last_cleanup = Time.current
  end
end

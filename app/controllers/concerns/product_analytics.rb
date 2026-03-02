module ProductAnalytics
  extend ActiveSupport::Concern

  private

  def track_event(event_name, **properties)
    return unless current_user

    RecordProductEventJob.perform_later(
      user_id: current_user.id,
      event_name: event_name,
      project_id: @project&.id,
      properties: properties.presence
    )
  end
end

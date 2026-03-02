module ProductEventTracker
  extend ActiveSupport::Concern

  private

  def track_product_event(event_name, user:, project: nil, **properties)
    RecordProductEventJob.perform_later(
      user_id: user.id,
      event_name: event_name,
      project_id: project&.id,
      properties: properties.presence
    )
  end
end

class RecordProductEventJob < ApplicationJob
  queue_as :low
  discard_on StandardError

  def perform(user_id:, event_name:, project_id: nil, properties: nil)
    ProductEvent.create!(
      user_id: user_id,
      event_name: event_name,
      project_id: project_id,
      properties: properties
    )
  end
end

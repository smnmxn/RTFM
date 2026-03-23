class RecordProductEventJob < ApplicationJob
  queue_as :low
  discard_on(StandardError) do |job, error|
    Rollbar.warning(error, job_class: job.class.name, job_id: job.job_id)
  end

  def perform(user_id:, event_name:, project_id: nil, properties: nil)
    ProductEvent.create!(
      user_id: user_id,
      event_name: event_name,
      project_id: project_id,
      properties: properties
    )
  end
end

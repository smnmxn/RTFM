class SendAdminNotificationJob < ApplicationJob
  queue_as :low
  discard_on(StandardError) do |job, error|
    Rollbar.warning(error, job_class: job.class.name, job_id: job.job_id)
  end

  def perform(product_event_id:)
    event = ProductEvent.find_by(id: product_event_id)
    return unless event

    config = AdminNotificationDispatcher::NOTIFIABLE_EVENTS[event.event_name]
    return unless config

    AdminNotificationDispatcher::CHANNELS.each do |channel|
      channel.notify(event: event, config: config)
    rescue => e
      Rails.logger.error("[AdminNotification] #{channel.name} failed: #{e.message}")
    end
  end
end

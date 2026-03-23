class ApplicationJob < ActiveJob::Base
  # Report all unhandled job errors to Rollbar with job context, then re-raise
  # so Sidekiq retry logic still works.
  rescue_from StandardError do |exception|
    Rollbar.error(exception,
      job_class: self.class.name,
      job_id: job_id,
      queue_name: queue_name
    )
    raise exception
  end
end

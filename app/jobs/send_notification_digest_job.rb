class SendNotificationDigestJob < ApplicationJob
  queue_as :default

  def perform(project_id:)
    project = Project.find_by(id: project_id)
    return unless project

    user = project.user

    # If jobs have started again since we were enqueued, bail out.
    # The next completing job will re-trigger this job.
    return if project.has_running_jobs?

    # If the user is online they already saw the toasts — no email needed.
    pending = project.pending_notifications.order(:created_at)
    if user.online?
      pending.delete_all
      return
    end

    # Check master email toggle
    unless user.email_notifications_enabled?
      pending.delete_all
      return
    end

    # Filter out event types the user has disabled
    notifications = pending.select { |n| user.email_event_enabled?(n.event_type) }

    if notifications.any?
      NotificationMailer.digest(user: user, project: project, notifications: notifications).deliver_now
    end

    # Always clean up all pending notifications for this project
    pending.delete_all
  end
end

module ToastNotifier
  extend ActiveSupport::Concern

  private

  # Broadcast a toast notification to the project's notifications stream.
  #
  # @param project [Project] the project to broadcast to
  # @param message [String] the toast message text
  # @param type [String] "success", "error", or "info"
  # @param action_url [String, nil] optional URL for the action link
  # @param action_label [String] label for the action link (default: "View")
  # @param event_type [String, nil] event type for email digest (e.g. "analysis_complete")
  # @param notification_metadata [Hash, nil] structured context for richer email content
  def broadcast_toast(project, message:, type: "success", action_url: nil, action_label: "View", event_type: nil, notification_metadata: nil)
    Turbo::StreamsChannel.broadcast_append_to(
      [ project, :notifications ],
      target: "toast-container",
      partial: "shared/toast",
      locals: {
        message: message,
        type: type,
        action_url: action_url,
        action_label: action_label,
        persistent: type == "error"
      }
    )

    # Record pending notification for email digest
    if event_type.present?
      record_pending_notification(project, event_type: event_type, type: type, message: message, action_url: action_url, metadata: notification_metadata)
    end
  end

  def record_pending_notification(project, event_type:, type:, message:, action_url:, metadata: nil)
    PendingNotification.create!(
      user: project.user,
      project: project,
      event_type: event_type,
      status: type,
      message: message,
      action_url: action_url,
      metadata: metadata
    )

    # Check if all running jobs for this project have finished
    unless project.reload.has_running_jobs?
      SendNotificationDigestJob.set(wait: 30.seconds).perform_later(project_id: project.id)
    end
  rescue => e
    Rails.logger.error "[ToastNotifier] Failed to record pending notification: #{e.message}"
  end
end

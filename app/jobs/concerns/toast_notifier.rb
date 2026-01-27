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
  def broadcast_toast(project, message:, type: "success", action_url: nil, action_label: "View")
    Turbo::StreamsChannel.broadcast_append_to(
      [project, :notifications],
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
  end
end

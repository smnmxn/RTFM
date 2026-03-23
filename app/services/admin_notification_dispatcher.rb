class AdminNotificationDispatcher
  NOTIFIABLE_EVENTS = {
    "user.signed_up" => {
      subject: "New signup",
      message: ->(event) {
        name = event.user.name.presence || event.user.email
        "#{name} (#{event.user.email}) just signed up."
      }
    },
    "user.plan_changed" => {
      subject: "Plan change",
      message: ->(event) {
        from = event.properties&.dig("from") || "unknown"
        to = event.properties&.dig("to") || "unknown"
        "#{event.user.email} changed plan: #{from} \u2192 #{to}"
      }
    },
    "project.created" => {
      subject: "New project",
      message: ->(event) {
        "#{event.user.email} created a new project."
      }
    },
    "project.onboarding_completed" => {
      subject: "Onboarding completed",
      message: ->(event) {
        "#{event.user.email} completed onboarding for '#{event.project&.name}'."
      }
    },
    "article.published" => {
      subject: "Article published",
      message: ->(event) {
        "#{event.user.email} published an article in '#{event.project&.name}'."
      }
    },
    "settings.custom_domain_verified" => {
      subject: "Custom domain verified",
      message: ->(event) {
        domain = event.properties&.dig("domain") || "unknown"
        "#{event.user.email} verified custom domain: #{domain}"
      }
    }
  }.freeze

  CHANNELS = [
    AdminNotification::EmailChannel
  ].freeze

  def self.dispatch(product_event)
    return unless NOTIFIABLE_EVENTS.key?(product_event.event_name)

    SendAdminNotificationJob.perform_later(product_event_id: product_event.id)
  end
end

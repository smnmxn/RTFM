class AdminNotificationDispatcher
  NOTIFIABLE_EVENTS = {
    "user.signed_up" => {
      subject: ->(event) { "New signup: #{event.user.email}" },
      message: ->(event) {
        name = event.user.name.presence || event.user.email
        "#{name} (#{event.user.email}) just signed up."
      }
    },
    "user.plan_changed" => {
      subject: ->(event) { "Plan change: #{event.user.email}" },
      message: ->(event) {
        from = event.properties&.dig("from") || "unknown"
        to = event.properties&.dig("to") || "unknown"
        "#{event.user.email} changed plan: #{from} \u2192 #{to}"
      }
    },
    "project.created" => {
      subject: ->(event) { "New project: #{event.user.email}" },
      message: ->(event) {
        "#{event.user.email} created a new project."
      }
    },
    "project.onboarding_completed" => {
      subject: ->(event) { "Onboarding completed: #{event.user.email}" },
      message: ->(event) {
        "#{event.user.email} completed onboarding for '#{event.project&.name}'."
      }
    },
    "article.published" => {
      subject: ->(event) { "Article published: #{event.user.email}" },
      message: ->(event) {
        "#{event.user.email} published an article in '#{event.project&.name}'."
      }
    },
    "settings.custom_domain_verified" => {
      subject: ->(event) { "Custom domain verified: #{event.user.email}" },
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

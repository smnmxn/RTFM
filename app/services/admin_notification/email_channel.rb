module AdminNotification
  class EmailChannel
    def self.notify(event:, config:)
      admins = User.where(admin: true)
      return if admins.empty?

      subject = config[:subject]
      message = config[:message].call(event)

      admins.each do |admin|
        AdminMailer.event_notification(
          admin: admin,
          subject: subject,
          message: message,
          event: event
        ).deliver_later
      end
    end
  end
end

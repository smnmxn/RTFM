class AdminMailer < ApplicationMailer
  def event_notification(admin:, subject:, message:, event:)
    @admin = admin
    @message = message
    @event = event
    @user = event.user
    @project = event.project
    @timestamp = event.created_at

    mail(to: admin.email, subject: "[Admin] #{subject}")
  end
end

class PaymentFailedNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # TODO: Send payment failed notification email
    Rails.logger.info("[Billing] Payment failed for user #{user.email}")
  end
end

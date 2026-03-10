class TrialEndingNotificationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # TODO: Send trial ending notification email
    Rails.logger.info("[Billing] Trial ending soon for user #{user.email}")
  end
end

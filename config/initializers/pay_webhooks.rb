# Sync user.plan when Pay subscription state changes
%w[
  pay.subscription.active
  pay.subscription.canceled
  pay.subscription.past_due
  pay.subscription.trialing
].each do |event|
  ActiveSupport::Notifications.subscribe(event) do |_name, _start, _finish, _id, payload|
    pay_subscription = payload[:pay_subscription]
    user = pay_subscription&.customer&.owner
    user&.sync_plan_from_subscription!
  end
end

# Stripe-specific webhook events via Pay delegator
Pay::Webhooks.delegator.subscribe("stripe.customer.subscription.trial_will_end") do |event|
  pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: event.data.object.customer)
  if pay_customer&.owner
    TrialEndingNotificationJob.perform_later(pay_customer.owner.id)
  end
end

Pay::Webhooks.delegator.subscribe("stripe.invoice.payment_failed") do |event|
  pay_customer = Pay::Customer.find_by(processor: :stripe, processor_id: event.data.object.customer)
  if pay_customer&.owner
    PaymentFailedNotificationJob.perform_later(pay_customer.owner.id)
  end
end

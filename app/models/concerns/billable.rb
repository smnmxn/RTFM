module Billable
  extend ActiveSupport::Concern

  def free?
    plan == "free"
  end

  def pro?
    plan == "pro"
  end

  def enterprise?
    plan == "enterprise"
  end

  def pro_or_above?
    pro? || enterprise?
  end

  def on_trial?
    trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_days_remaining
    return 0 unless on_trial?
    ((trial_ends_at - Time.current) / 1.day).ceil
  end

  def plan_past_due?
    plan_status == "past_due"
  end

  def active_subscription
    payment_processor&.subscription
  end

  def plan_limit(feature)
    PlanLimits.for(plan)[feature]
  end

  def within_plan_limit?(feature, count)
    limit = plan_limit(feature)
    return true if limit == Float::INFINITY
    count < limit
  end

  def sync_plan_from_subscription!
    return if enterprise? # Enterprise is admin-set only

    old_plan = plan
    sub = active_subscription

    if sub.nil? || sub.ends_at&.past?
      update!(plan: "free", plan_status: "active", trial_ends_at: nil)
      fire_plan_change_event(old_plan, "free") if old_plan != "free"
      return
    end

    new_status = case sub.status
    when "active" then "active"
    when "trialing" then "active"
    when "past_due" then "past_due"
    else "active"
    end

    new_trial_ends_at = sub.trial_ends_at

    update!(plan: "pro", plan_status: new_status, trial_ends_at: new_trial_ends_at)
    fire_plan_change_event(old_plan, "pro") if old_plan != "pro"
  end

  private

  def fire_plan_change_event(from_plan, to_plan)
    RecordProductEventJob.perform_later(
      user_id: id,
      event_name: "user.plan_changed",
      properties: { from: from_plan, to: to_plan }
    )
  end
end

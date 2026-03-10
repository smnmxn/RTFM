require "test_helper"

class BillableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "free? returns true for free plan" do
    @user.plan = "free"
    assert @user.free?
    assert_not @user.pro?
    assert_not @user.enterprise?
  end

  test "pro? returns true for pro plan" do
    @user.plan = "pro"
    assert @user.pro?
    assert_not @user.free?
  end

  test "enterprise? returns true for enterprise plan" do
    @user.plan = "enterprise"
    assert @user.enterprise?
  end

  test "pro_or_above? returns true for pro and enterprise" do
    @user.plan = "pro"
    assert @user.pro_or_above?

    @user.plan = "enterprise"
    assert @user.pro_or_above?

    @user.plan = "free"
    assert_not @user.pro_or_above?
  end

  test "on_trial? returns true when trial_ends_at is in the future" do
    @user.trial_ends_at = 5.days.from_now
    assert @user.on_trial?

    @user.trial_ends_at = 1.day.ago
    assert_not @user.on_trial?

    @user.trial_ends_at = nil
    assert_not @user.on_trial?
  end

  test "trial_days_remaining returns correct count" do
    @user.trial_ends_at = 5.days.from_now
    assert_equal 5, @user.trial_days_remaining

    @user.trial_ends_at = nil
    assert_equal 0, @user.trial_days_remaining
  end

  test "plan_past_due? checks plan_status" do
    @user.plan_status = "past_due"
    assert @user.plan_past_due?

    @user.plan_status = "active"
    assert_not @user.plan_past_due?
  end

  test "plan_limit returns correct limits for plan" do
    @user.plan = "free"
    assert_equal 1, @user.plan_limit(:projects)
    assert_equal 100, @user.plan_limit(:ai_answers_per_month)
    assert_equal false, @user.plan_limit(:custom_domain)

    @user.plan = "pro"
    assert_equal Float::INFINITY, @user.plan_limit(:projects)
    assert_equal true, @user.plan_limit(:custom_domain)
  end

  test "within_plan_limit? checks count against limit" do
    @user.plan = "free"
    assert @user.within_plan_limit?(:projects, 0)
    assert_not @user.within_plan_limit?(:projects, 1)

    @user.plan = "pro"
    assert @user.within_plan_limit?(:projects, 1000)
  end
end

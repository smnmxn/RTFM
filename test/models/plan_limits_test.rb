require "test_helper"

class PlanLimitsTest < ActiveSupport::TestCase
  test "returns limits for known plans" do
    assert_equal 1, PlanLimits.for("free")[:projects]
    assert_equal Float::INFINITY, PlanLimits.for("pro")[:projects]
    assert_equal Float::INFINITY, PlanLimits.for("enterprise")[:projects]
  end

  test "returns free limits for unknown plan" do
    assert_equal 1, PlanLimits.for("unknown")[:projects]
  end

  test "free plan has correct limits" do
    limits = PlanLimits.for("free")
    assert_equal 1, limits[:projects]
    assert_equal 1, limits[:team_members]
    assert_equal 100, limits[:ai_answers_per_month]
    assert_equal false, limits[:custom_domain]
    assert_equal false, limits[:custom_branding]
    assert_equal false, limits[:analytics]
    assert_equal false, limits[:remove_badge]
  end

  test "pro plan has correct limits" do
    limits = PlanLimits.for("pro")
    assert_equal Float::INFINITY, limits[:projects]
    assert_equal 10, limits[:team_members]
    assert_equal Float::INFINITY, limits[:ai_answers_per_month]
    assert_equal true, limits[:custom_domain]
    assert_equal true, limits[:custom_branding]
    assert_equal true, limits[:analytics]
    assert_equal true, limits[:remove_badge]
  end

  test "limits are frozen" do
    assert PlanLimits::LIMITS.frozen?
    assert PlanLimits::LIMITS["free"].frozen?
  end
end

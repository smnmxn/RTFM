require "test_helper"

class HelpCentreRateLimiterTest < ActiveSupport::TestCase
  setup do
    @project = projects(:one)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @limiter = HelpCentreRateLimiter.new(@project)
  end

  teardown do
    Rails.cache = @original_cache
  end

  # ========================================
  # Monthly limit (plan-based)
  # ========================================

  test "monthly_limit reflects user plan" do
    assert_equal 100, @limiter.monthly_limit
  end

  test "pro user has unlimited monthly limit" do
    @project.user.update!(plan: "pro")
    limiter = HelpCentreRateLimiter.new(@project)
    assert_equal Float::INFINITY, limiter.monthly_limit
  end

  test "free user is rate limited after 100 monthly requests" do
    key = "help_centre:rate_limit:monthly:user_#{@project.user.id}:#{Time.current.strftime('%Y%m')}"
    Rails.cache.write(key, 100, expires_in: 30.days)

    limiter = HelpCentreRateLimiter.new(@project)
    assert limiter.exceeded?
  end

  test "free user is not rate limited below 100 monthly requests" do
    key = "help_centre:rate_limit:monthly:user_#{@project.user.id}:#{Time.current.strftime('%Y%m')}"
    Rails.cache.write(key, 99, expires_in: 30.days)

    limiter = HelpCentreRateLimiter.new(@project)
    assert_not limiter.exceeded?
  end

  test "pro user is not rate limited at 100 monthly requests" do
    @project.user.update!(plan: "pro")
    key = "help_centre:rate_limit:monthly:user_#{@project.user.id}:#{Time.current.strftime('%Y%m')}"
    Rails.cache.write(key, 100, expires_in: 30.days)

    limiter = HelpCentreRateLimiter.new(@project)
    assert_not limiter.exceeded?
  end

  test "increment! increments monthly counter" do
    @limiter.increment!
    key = "help_centre:rate_limit:monthly:user_#{@project.user.id}:#{Time.current.strftime('%Y%m')}"
    assert_equal 1, Rails.cache.read(key).to_i
  end

  test "limit_info includes monthly data" do
    info = @limiter.limit_info
    assert info.key?(:monthly)
    assert_equal 0, info[:monthly][:count]
    assert_equal 100, info[:monthly][:limit]
    assert_equal false, info[:monthly][:exceeded]
  end

  test "monthly key is scoped per user not per project" do
    # Two projects owned by same user should share the monthly counter
    project2 = projects(:one_second)
    assert_equal @project.user_id, project2.user_id

    @limiter.increment!

    limiter2 = HelpCentreRateLimiter.new(project2)
    assert_equal 1, limiter2.limit_info[:monthly][:count]
  end
end

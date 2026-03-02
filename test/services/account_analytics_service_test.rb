require "test_helper"

class AccountAnalyticsServiceTest < ActiveSupport::TestCase
  setup do
    @user_one = users(:one)
    @user_two = users(:two)
    @project_one = projects(:one)
    @project_two = projects(:two)
    @start_date = 30.days.ago
    @end_date = Time.current

    # Project one (user one): full lifecycle
    ProductEvent.create!(user: @user_one, event_name: "project.created", project: @project_one, created_at: 10.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "project.onboarding_step_completed", project: @project_one, properties: { "step" => "repository" }, created_at: 10.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "project.onboarding_step_completed", project: @project_one, properties: { "step" => "setup" }, created_at: 9.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "project.onboarding_step_completed", project: @project_one, properties: { "step" => "analyze" }, created_at: 9.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "project.onboarding_step_completed", project: @project_one, properties: { "step" => "sections" }, created_at: 8.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "project.onboarding_completed", project: @project_one, created_at: 8.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.generated", project: @project_one, properties: { "article_id" => 100 }, created_at: 7.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.approved", project: @project_one, properties: { "article_id" => 100 }, created_at: 6.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.edited", project: @project_one, properties: { "article_id" => 100, "field" => "title" }, created_at: 6.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.published", project: @project_one, properties: { "article_id" => 100 }, created_at: 5.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.generated", project: @project_one, properties: { "article_id" => 101 }, created_at: 4.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.approved", project: @project_one, properties: { "article_id" => 101 }, created_at: 3.days.ago)
    ProductEvent.create!(user: @user_one, event_name: "article.published", project: @project_one, properties: { "article_id" => 101 }, created_at: 2.days.ago)

    # Project two (user two): minimal activity
    ProductEvent.create!(user: @user_two, event_name: "project.created", project: @project_two, created_at: 15.days.ago)
    ProductEvent.create!(user: @user_two, event_name: "project.onboarding_step_completed", project: @project_two, properties: { "step" => "repository" }, created_at: 15.days.ago)
  end

  test "#call returns array of project summaries" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    assert_kind_of Array, results
    # Each entry should have a :project key
    results.each { |r| assert r[:project].is_a?(Project) }

    project_one_entry = results.find { |a| a[:project].id == @project_one.id }
    assert_not_nil project_one_entry
    assert_equal @user_one, project_one_entry[:user]
    assert_equal 2, project_one_entry[:articles_published]
    assert project_one_entry[:ttfv_minutes].present?
    assert project_one_entry[:ttfv_minutes] > 0
  end

  test "#call computes approval rate per project" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    project_one_entry = results.find { |a| a[:project].id == @project_one.id }
    # 2 approved, 0 rejected = 100%
    assert_equal 100.0, project_one_entry[:approval_rate]
  end

  test "#call computes edit rate per project" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    project_one_entry = results.find { |a| a[:project].id == @project_one.id }
    # 2 published, 1 edited = 50%
    assert_equal 50.0, project_one_entry[:edit_rate]
  end

  test "#call sorts by most recently active first" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    # Filter to only entries with activity
    active = results.select { |a| a[:last_active_at].present? }
    assert active.size >= 2

    # Should be sorted descending by last_active_at
    active.each_cons(2) do |a, b|
      assert a[:last_active_at] >= b[:last_active_at], "Projects not sorted by most recent first"
    end
  end

  test "#call includes custom_domain for active domains" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    cd_active = projects(:custom_domain_active)
    cd_entry = results.find { |a| a[:project].id == cd_active.id }
    assert_not_nil cd_entry
    assert cd_entry[:custom_domain].present?
  end

  test "#call includes articles_count and onboarding_status" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    project_one_entry = results.find { |a| a[:project].id == @project_one.id }
    assert project_one_entry.key?(:articles_count)
    assert project_one_entry.key?(:onboarding_status)
  end

  test "#call handles project with no events" do
    ProductEvent.where(project_id: @project_two.id).delete_all

    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    project_two_entry = results.find { |a| a[:project].id == @project_two.id }
    assert_not_nil project_two_entry
    assert_equal 0, project_two_entry[:total_events]
    assert_nil project_two_entry[:last_active_at]
  end

  test "#project_detail returns detailed hash for project" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    detail = service.project_detail(@project_one)

    assert_equal @project_one, detail[:project]
    assert_equal @user_one, detail[:user]
    assert_equal 2, detail[:articles_published]
    assert detail[:ttfv_minutes].present?
    assert_equal 100.0, detail[:approval_rate]
    assert_equal 2, detail[:articles_reviewed]
    assert_equal 50.0, detail[:edit_rate]
    assert detail[:recent_events].size >= 1
    assert detail[:total_events_in_period] >= 13
  end

  test "#project_detail includes article lifecycle breakdown" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    detail = service.project_detail(@project_one)

    lifecycle = detail[:article_lifecycle]
    assert_not_nil lifecycle
    assert_equal 2, lifecycle[:generated]
    assert_equal 2, lifecycle[:approved]
    assert_equal 0, lifecycle[:rejected]
    assert_equal 2, lifecycle[:published]
  end

  test "#project_detail recent events are ordered newest first" do
    service = AccountAnalyticsService.new(@start_date, @end_date)
    detail = service.project_detail(@project_one)

    events = detail[:recent_events].to_a
    events.each_cons(2) do |a, b|
      assert a.created_at >= b.created_at, "Events not sorted newest first"
    end
  end

  test "#project_detail handles project with no events" do
    ProductEvent.where(project_id: @project_two.id).delete_all

    service = AccountAnalyticsService.new(@start_date, @end_date)
    detail = service.project_detail(@project_two)

    assert_equal @project_two, detail[:project]
    assert_equal @user_two, detail[:user]
    assert_nil detail[:approval_rate]
    assert_nil detail[:edit_rate]
    assert_nil detail[:ttfv_minutes]
    assert_equal 0, detail[:articles_published]
    assert_equal 0, detail[:total_events_in_period]
  end

  test "handles empty database gracefully" do
    ProductEvent.delete_all

    service = AccountAnalyticsService.new(@start_date, @end_date)
    results = service.call

    # Should still return entries for all projects
    assert results.any?
    results.each do |entry|
      assert_equal 0, entry[:total_events]
      assert_nil entry[:last_active_at]
      assert_nil entry[:approval_rate]
    end
  end
end

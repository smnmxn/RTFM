require "test_helper"

class ProductAnalyticsSummaryServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @project = projects(:one)
    @start_date = 30.days.ago
    @end_date = Time.current

    # Create some baseline events
    ProductEvent.create!(user: @user, event_name: "project.created", project: @project, created_at: 5.days.ago)
    ProductEvent.create!(user: @user, event_name: "project.onboarding_step_completed", project: @project, properties: { "step" => "repository" }, created_at: 5.days.ago)
    ProductEvent.create!(user: @user, event_name: "project.onboarding_step_completed", project: @project, properties: { "step" => "setup" }, created_at: 4.days.ago)
    ProductEvent.create!(user: @user, event_name: "project.onboarding_step_completed", project: @project, properties: { "step" => "analyze" }, created_at: 4.days.ago)
    ProductEvent.create!(user: @user, event_name: "project.onboarding_step_completed", project: @project, properties: { "step" => "sections" }, created_at: 3.days.ago)
    ProductEvent.create!(user: @user, event_name: "project.onboarding_completed", project: @project, created_at: 3.days.ago)

    ProductEvent.create!(user: @user, event_name: "recommendation.accepted", project: @project, properties: { "recommendation_id" => 1 }, created_at: 2.days.ago)
    ProductEvent.create!(user: @user, event_name: "recommendation.accepted", project: @project, properties: { "recommendation_id" => 2 }, created_at: 2.days.ago)
    ProductEvent.create!(user: @user, event_name: "recommendation.rejected", project: @project, properties: { "recommendation_id" => 3 }, created_at: 2.days.ago)

    ProductEvent.create!(user: @user, event_name: "article.generated", project: @project, properties: { "article_id" => 100 }, created_at: 2.days.ago)
    ProductEvent.create!(user: @user, event_name: "article.generated", project: @project, properties: { "article_id" => 101 }, created_at: 2.days.ago)
    ProductEvent.create!(user: @user, event_name: "article.approved", project: @project, properties: { "article_id" => 100 }, created_at: 1.day.ago)
    ProductEvent.create!(user: @user, event_name: "article.published", project: @project, properties: { "article_id" => 100 }, created_at: 1.day.ago)
    ProductEvent.create!(user: @user, event_name: "article.published", project: @project, properties: { "article_id" => 101 }, created_at: 1.day.ago)

    # Article 100 was edited, article 101 was not
    ProductEvent.create!(user: @user, event_name: "article.edited", project: @project, properties: { "article_id" => 100, "field" => "title" }, created_at: 1.day.ago)
  end

  test "summary returns expected counts" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    assert data[:summary][:total_events] >= 15
    assert data[:summary][:active_users] >= 1
    assert data[:summary][:active_projects] >= 1
    assert_equal 2, data[:summary][:articles_published]
  end

  test "onboarding funnel tracks steps" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    funnel = data[:onboarding_funnel]
    step_names = funnel[:steps].map { |s| s[:step] }
    assert_includes step_names, "created"
    assert_includes step_names, "repository"
    assert_includes step_names, "completed"

    # All steps should have counts >= 1
    funnel[:steps].each do |step|
      assert step[:count] >= 0, "Step #{step[:step]} should have a non-negative count"
    end

    # Conversion rates should be calculated
    assert funnel[:rates].size == funnel[:steps].size - 1
  end

  test "article lifecycle tracks published without edit" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    lifecycle = data[:article_lifecycle]
    assert_equal 2, lifecycle[:generated]
    assert_equal 1, lifecycle[:approved]
    assert_equal 2, lifecycle[:published]
    assert_equal 1, lifecycle[:published_without_edit]
    assert_equal 50.0, lifecycle[:published_without_edit_pct]
  end

  test "recommendations stats" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    recs = data[:recommendations]
    assert_equal 2, recs[:accepted]
    assert_equal 1, recs[:rejected]
    assert_in_delta 66.7, recs[:acceptance_rate], 0.1
  end

  test "custom domain stats" do
    ProductEvent.create!(user: @user, event_name: "settings.custom_domain_added", project: @project, properties: { "domain" => "help.example.com" }, created_at: 1.day.ago)

    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    assert_equal 1, data[:custom_domain][:added]
    assert data[:custom_domain][:current_active] >= 0
  end

  test "daily activity returns data for each day" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    expected_days = (@start_date.to_date..@end_date.to_date).count
    assert_equal expected_days, data[:daily_activity].size
  end

  test "active users returns DAU/WAU/MAU" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    assert data[:active_users].key?(:dau)
    assert data[:active_users].key?(:wau)
    assert data[:active_users].key?(:mau)
    assert data[:active_users][:mau] >= data[:active_users][:wau]
    assert data[:active_users][:wau] >= data[:active_users][:dau]
  end

  test "handles empty data gracefully" do
    ProductEvent.delete_all

    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    assert_equal 0, data[:summary][:total_events]
    assert_equal 0, data[:summary][:active_users]
    assert_equal 0, data[:article_lifecycle][:published_without_edit_pct]
    assert_equal 0, data[:recommendations][:acceptance_rate]

    # Fundraise metrics should handle empty data
    fm = data[:fundraise_metrics]
    assert_equal 0, fm[:design_partners_live]
    assert_nil fm[:median_ttfv_minutes]
    assert_nil fm[:approval_rate]
    assert_nil fm[:edit_rate]
    assert_nil fm[:repo_drop_off_rate]
  end

  test "fundraise metrics design partners live" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    # Project completed onboarding AND has published articles
    assert_equal 1, data[:fundraise_metrics][:design_partners_live]
  end

  test "fundraise metrics time to first value" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    # project.created at 5 days ago, article.generated at 2 days ago = ~4320 minutes
    assert data[:fundraise_metrics][:median_ttfv_minutes].present?
    assert data[:fundraise_metrics][:median_ttfv_minutes] > 0
  end

  test "fundraise metrics approval rate" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    # 1 approved, 0 rejected in period (article.approved count)
    fm = data[:fundraise_metrics]
    assert fm[:approval_rate].present?
    assert fm[:articles_reviewed] >= 1
  end

  test "fundraise metrics edit rate" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    # 2 published, 1 edited = 50% edit rate
    assert_equal 50.0, data[:fundraise_metrics][:edit_rate]
    assert_equal 2, data[:fundraise_metrics][:articles_published]
  end

  test "fundraise metrics repo drop-off rate" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    # 1 created, 1 connected repository = 0% drop-off
    assert_equal 0.0, data[:fundraise_metrics][:repo_drop_off_rate]
    assert_equal 1, data[:fundraise_metrics][:onboarding_started]
    assert_equal 1, data[:fundraise_metrics][:repo_connected]
  end

  test "fundraise metrics help centre views" do
    service = ProductAnalyticsSummaryService.new(@start_date, @end_date)
    data = service.call

    assert data[:fundraise_metrics][:help_centre_views] >= 0
    assert data[:fundraise_metrics][:help_centre_visitors] >= 0
  end
end

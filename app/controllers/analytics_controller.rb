class AnalyticsController < ApplicationController
  before_action :require_admin

  PERIODS = {
    "24h" => 1,
    "7d" => 7,
    "30d" => 30,
    "90d" => 90
  }.freeze

  def show
    @period = PERIODS.key?(params[:period]) ? params[:period] : "30d"
    @tab = %w[public product projects visitors help_centres].include?(params[:tab]) ? params[:tab] : "public"
    days = PERIODS[@period]

    end_date = Time.current
    start_date = days.days.ago

    if @tab == "visitors"
      # Sorting
      sort_column = params[:sort].presence_in(%w[visitor_id email total_page_views total_events utm_source device_type first_seen_at last_seen_at]) || "last_seen_at"
      sort_direction = params[:direction].presence_in(%w[asc desc]) || "desc"

      @visitors = Visitor.where("last_seen_at >= ?", start_date)
                         .order("#{sort_column} #{sort_direction}")
                         .page(params[:page])
                         .per(50)

      @sort_column = sort_column
      @sort_direction = sort_direction
    elsif @tab == "help_centres"
      @help_centres = HelpCentreAnalyticsService.new(start_date, end_date, @period).call
    elsif @tab == "projects"
      @projects = AccountAnalyticsService.new(start_date, end_date).call
    elsif @tab == "product"
      service = ProductAnalyticsSummaryService.new(start_date, end_date)
      @data = service.call
    else
      service = AnalyticsSummaryService.new(start_date, end_date, @period)
      @data = service.call
    end
  end

  def project_detail
    @period = PERIODS.key?(params[:period]) ? params[:period] : "30d"
    days = PERIODS[@period]
    end_date = Time.current
    start_date = days.days.ago

    @project = Project.find(params[:id])
    @user = @project.user
    @detail = AccountAnalyticsService.new(start_date, end_date).project_detail(@project)
  end

  def help_centre_detail
    @period = PERIODS.key?(params[:period]) ? params[:period] : "30d"
    days = PERIODS[@period]
    end_date = Time.current
    start_date = days.days.ago

    @project = Project.find_by!(slug: params[:id])
    @user = @project.user
    @detail = HelpCentreAnalyticsService.new(start_date, end_date, @period).project_detail(@project)
  end

  def visitor_detail
    @visitor = Visitor.find(params[:id])
    @events = @visitor.analytics_events.order(created_at: :desc).limit(100)

    # Group events by type for summary
    @event_summary = @events.group_by(&:event_type).transform_values(&:count)

    # Get daily activity for the last 30 days
    @daily_activity = @visitor.analytics_events
                               .where("created_at >= ?", 30.days.ago)
                               .group_by { |e| e.created_at.to_date }
                               .transform_values(&:count)
                               .sort
                               .to_h
  end
end

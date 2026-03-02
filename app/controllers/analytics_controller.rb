class AnalyticsController < ApplicationController
  before_action :require_admin

  PERIODS = {
    "7d" => 7,
    "30d" => 30,
    "90d" => 90
  }.freeze

  def show
    @period = PERIODS.key?(params[:period]) ? params[:period] : "30d"
    @tab = %w[public product projects].include?(params[:tab]) ? params[:tab] : "public"
    days = PERIODS[@period]

    end_date = Time.current
    start_date = days.days.ago

    if @tab == "projects"
      @projects = AccountAnalyticsService.new(start_date, end_date).call
    elsif @tab == "product"
      service = ProductAnalyticsSummaryService.new(start_date, end_date)
      @data = service.call
    else
      service = AnalyticsSummaryService.new(start_date, end_date)
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
end

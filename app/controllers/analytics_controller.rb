class AnalyticsController < ApplicationController
  before_action :require_admin

  PERIODS = {
    "7d" => 7,
    "30d" => 30,
    "90d" => 90
  }.freeze

  def show
    @period = PERIODS.key?(params[:period]) ? params[:period] : "30d"
    days = PERIODS[@period]

    end_date = Time.current
    start_date = days.days.ago

    service = AnalyticsSummaryService.new(start_date, end_date)
    @data = service.call
  end
end

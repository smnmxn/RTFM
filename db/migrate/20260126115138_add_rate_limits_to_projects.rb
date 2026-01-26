class AddRateLimitsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :help_centre_hourly_limit, :integer, default: 20, null: false
    add_column :projects, :help_centre_daily_limit, :integer, default: 100, null: false
  end
end

class AddProjectIdToAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :analytics_events, :project_id, :bigint, null: true
    add_index :analytics_events, [:project_id, :created_at]
    add_index :analytics_events, [:project_id, :event_type, :created_at],
              name: "idx_analytics_events_project_event_created"
  end
end

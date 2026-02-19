class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events do |t|
      t.string :visitor_id, null: false, limit: 36
      t.string :event_type, null: false
      t.json :event_data
      t.string :page_path, null: false
      t.string :referrer_url
      t.string :referrer_host
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.string :device_type
      t.string :browser_family
      t.string :os_family
      t.datetime :created_at, null: false
    end

    add_index :analytics_events, [ :event_type, :created_at ]
    add_index :analytics_events, :created_at
    add_index :analytics_events, :visitor_id
  end
end

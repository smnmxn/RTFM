class CreateVisitors < ActiveRecord::Migration[8.1]
  def change
    create_table :visitors do |t|
      # Core identification
      t.string :visitor_id, limit: 36, null: false, index: { unique: true }

      # Attribution (first touch)
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.string :initial_referrer_url
      t.string :initial_referrer_host
      t.string :initial_landing_page

      # Last known information (enriched over time)
      t.string :last_ip_address
      t.string :last_user_agent, limit: 512
      t.string :device_type  # mobile, tablet, desktop
      t.string :browser_family  # Chrome, Firefox, Safari, Edge, Other
      t.string :os_family  # iOS, Windows, macOS, Android, Linux, Other

      # Identity (captured when available)
      t.string :email
      t.string :name
      t.integer :user_id
      t.datetime :identified_at

      # Activity tracking
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.integer :total_page_views, default: 0, null: false
      t.integer :total_events, default: 0, null: false

      t.timestamps
    end

    add_index :visitors, :last_seen_at
    add_index :visitors, :first_seen_at
    add_index :visitors, :email
    add_index :visitors, :user_id
  end
end

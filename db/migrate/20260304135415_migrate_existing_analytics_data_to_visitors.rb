class MigrateExistingAnalyticsDataToVisitors < ActiveRecord::Migration[8.1]
  def up
    # Get unique visitor_ids from analytics_events
    unique_visitor_ids = execute("SELECT DISTINCT visitor_id FROM analytics_events").map { |row| row['visitor_id'] }

    unique_visitor_ids.each do |visitor_id|
      # Get first event for attribution
      first_event = execute(<<-SQL.squish).first
        SELECT * FROM analytics_events
        WHERE visitor_id = '#{visitor_id}'
        ORDER BY created_at ASC
        LIMIT 1
      SQL

      # Get last event for current metadata
      last_event = execute(<<-SQL.squish).first
        SELECT * FROM analytics_events
        WHERE visitor_id = '#{visitor_id}'
        ORDER BY created_at DESC
        LIMIT 1
      SQL

      # Get counts
      counts = execute(<<-SQL.squish).first
        SELECT
          MIN(created_at) as first_seen,
          MAX(created_at) as last_seen,
          COUNT(*) as event_count,
          COUNT(CASE WHEN event_type = 'page_view' THEN 1 END) as page_view_count
        FROM analytics_events
        WHERE visitor_id = '#{visitor_id}'
      SQL

      # Insert visitor record
      execute(<<-SQL.squish)
        INSERT INTO visitors (
          visitor_id,
          utm_source,
          utm_medium,
          utm_campaign,
          utm_term,
          utm_content,
          initial_referrer_url,
          initial_referrer_host,
          initial_landing_page,
          last_user_agent,
          device_type,
          browser_family,
          os_family,
          first_seen_at,
          last_seen_at,
          total_events,
          total_page_views,
          created_at,
          updated_at
        ) VALUES (
          '#{visitor_id}',
          #{sanitize(first_event['utm_source'])},
          #{sanitize(first_event['utm_medium'])},
          #{sanitize(first_event['utm_campaign'])},
          #{sanitize(first_event['utm_term'])},
          #{sanitize(first_event['utm_content'])},
          #{sanitize(first_event['referrer_url'])},
          #{sanitize(first_event['referrer_host'])},
          #{sanitize(first_event['page_path'])},
          #{sanitize(last_event['user_agent'])},
          #{sanitize(last_event['device_type'])},
          #{sanitize(last_event['browser_family'])},
          #{sanitize(last_event['os_family'])},
          '#{counts['first_seen']}',
          '#{counts['last_seen']}',
          #{counts['event_count']},
          #{counts['page_view_count']},
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end
  end

  def down
    execute("DELETE FROM visitors")
  end

  private

  def sanitize(value)
    return "NULL" if value.nil?
    "'#{value.to_s.gsub("'", "''")}'"
  end
end

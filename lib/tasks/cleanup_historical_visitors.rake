namespace :visitors do
  desc "Remove historical visitors with 'Other' browser (incomplete tracking data)"
  task cleanup_historical: :environment do
    puts "🧹 Cleaning up historical visitors with incomplete data..."
    puts "=" * 60

    # Find visitors with "Other" or NULL browser
    other_browser_visitors = Visitor.where(browser_family: ["Other", nil])

    puts "Found #{other_browser_visitors.count} visitors with 'Other' or missing browser"

    if other_browser_visitors.count == 0
      puts "✅ No historical visitors to clean up!"
      next
    end

    # Show some samples
    puts "\nSample visitors to be removed:"
    other_browser_visitors.limit(10).each do |v|
      puts "  - #{v.visitor_id[0..11]}... | Browser: #{v.browser_family || '(nil)'} | Device: #{v.device_type} | OS: #{v.os_family}"
      puts "    UA: #{v.last_user_agent&.truncate(70) || '(empty)'}"
    end

    # Count events that will be deleted
    visitor_ids = other_browser_visitors.pluck(:visitor_id)
    events_count = AnalyticsEvent.where(visitor_id: visitor_ids).count

    puts "\nThis will delete:"
    puts "  - #{other_browser_visitors.count} visitors"
    puts "  - #{events_count} analytics events"

    # Check for CONFIRM environment variable (for non-interactive use)
    if ENV['CONFIRM'] == 'yes'
      confirmation = 'y'
      puts "\n✓ Auto-confirmed via CONFIRM=yes"
    else
      print "\n⚠️  Proceed with deletion? (y/N): "
      confirmation = STDIN.gets&.chomp&.downcase
    end

    if confirmation == 'y'
      puts "\n🗑️  Deleting..."

      # Delete analytics events first (foreign key constraint)
      deleted_events = AnalyticsEvent.where(visitor_id: visitor_ids).delete_all
      puts "  ✅ Deleted #{deleted_events} analytics events"

      # Delete visitors
      deleted_visitors = other_browser_visitors.delete_all
      puts "  ✅ Deleted #{deleted_visitors} visitors"

      # Show new stats
      remaining = Visitor.count
      puts "\n📊 Database now has #{remaining} visitors"

      if remaining > 0
        # Show breakdown
        breakdown = Visitor.group(:browser_family).count
        puts "\nBrowser breakdown:"
        breakdown.each do |browser, count|
          puts "  - #{browser || '(nil)'}: #{count}"
        end
      end

      puts "\n✅ Cleanup complete!"
    else
      puts "❌ Cancelled - no data deleted"
    end
  end
end

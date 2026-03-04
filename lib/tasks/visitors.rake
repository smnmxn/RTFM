namespace :visitors do
  desc "Remove suspected bot visitors from the database"
  task remove_bots: :environment do
    puts "🤖 Identifying and removing bot visitors..."

    # Find visitors that match bot patterns
    bot_patterns = /
      bot|crawl|spider|slurp|scrape|
      mediapartners|facebookexternalhit|bingpreview|
      lighthouse|pingdom|uptimerobot|statuscake|
      headlesschrome|phantomjs|selenium|webdriver|
      curl|wget|python|java|go-http|axios|
      postman|insomnia|httpie|
      ahrefsbot|semrushbot|mj12bot|dotbot|
      baidu|yandex|duckduckgo|
      monitoring|check_http|nagios|
      prerender|archive\.org|
      ia_archiver|wayback
    /ix

    # Find visitors with bot-like user agents (case-insensitive)
    bot_visitors = Visitor.where("LOWER(last_user_agent) LIKE ?", "%bot%")
                          .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%crawl%"))
                          .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%spider%"))
                          .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%scrape%"))

    # Find "Other/Other/Other" visitors (likely bots)
    other_visitors = Visitor.where(
      device_type: ["unknown", nil],
      browser_family: ["Other", nil],
      os_family: ["Other", nil]
    )

    # Find visitors with very short or blank user agents
    suspicious_visitors = Visitor.where("LENGTH(COALESCE(last_user_agent, '')) < 10")

    # Combine all suspect visitors
    all_suspects = (bot_visitors.pluck(:id) + other_visitors.pluck(:id) + suspicious_visitors.pluck(:id)).uniq

    if all_suspects.empty?
      puts "✅ No bot visitors found!"
      next
    end

    puts "Found #{all_suspects.count} suspected bot visitors"

    # Show some examples
    Visitor.where(id: all_suspects.first(5)).each do |v|
      puts "  - #{v.visitor_id[0..11]}... | #{v.last_user_agent&.truncate(60) || '(no user agent)'}"
    end

    print "\n⚠️  Delete these #{all_suspects.count} visitors and their events? (y/N): "
    confirmation = STDIN.gets.chomp.downcase

    if confirmation == 'y'
      # Delete analytics events first (foreign key constraint)
      deleted_events = AnalyticsEvent.where(visitor_id: Visitor.where(id: all_suspects).pluck(:visitor_id)).delete_all
      # Delete visitors
      deleted_visitors = Visitor.where(id: all_suspects).delete_all

      puts "✅ Deleted #{deleted_visitors} visitors and #{deleted_events} events"
    else
      puts "❌ Cancelled - no visitors deleted"
    end
  end

  desc "Show bot visitor statistics"
  task bot_stats: :environment do
    puts "🤖 Bot Visitor Statistics"
    puts "=" * 60

    total_visitors = Visitor.count

    # Other/Other/Other pattern
    other_visitors = Visitor.where(
      device_type: ["unknown", nil],
      browser_family: ["Other", nil],
      os_family: ["Other", nil]
    ).count

    # Bot patterns in user agent
    bot_user_agents = Visitor.where("LOWER(last_user_agent) LIKE ?", "%bot%")
                             .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%crawl%"))
                             .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%spider%"))
                             .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%curl%"))
                             .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%python%"))
                             .or(Visitor.where("LOWER(last_user_agent) LIKE ?", "%wget%"))
                             .count

    # Suspicious (very short user agents)
    suspicious = Visitor.where("LENGTH(COALESCE(last_user_agent, '')) < 10").count

    puts "Total Visitors: #{total_visitors}"
    puts "Other/Other/Other: #{other_visitors} (#{(other_visitors.to_f / total_visitors * 100).round(1)}%)"
    puts "Bot User Agents: #{bot_user_agents} (#{(bot_user_agents.to_f / total_visitors * 100).round(1)}%)"
    puts "Suspicious (short UA): #{suspicious} (#{(suspicious.to_f / total_visitors * 100).round(1)}%)"

    puts "\nSample Other/Other/Other visitors:"
    Visitor.where(
      device_type: ["unknown", nil],
      browser_family: ["Other", nil],
      os_family: ["Other", nil]
    ).limit(10).each do |v|
      puts "  - #{v.visitor_id[0..11]}... | #{v.last_user_agent&.truncate(60) || '(no user agent)'}"
    end
  end
end

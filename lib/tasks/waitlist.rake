namespace :waitlist do
  desc "List all waitlist entries"
  task list: :environment do
    entries = WaitlistEntry.order(created_at: :desc)

    puts "=== Waitlist (#{entries.count} entries) ==="
    if entries.any?
      entries.each do |entry|
        puts "  #{entry.email} (joined #{entry.created_at.strftime('%Y-%m-%d %H:%M')})"
      end
    else
      puts "  (empty)"
    end
  end

  desc "Export waitlist emails to CSV"
  task export: :environment do
    entries = WaitlistEntry.order(created_at: :asc)

    if entries.empty?
      puts "Waitlist is empty."
    else
      puts "email,joined_at"
      entries.each do |entry|
        puts "#{entry.email},#{entry.created_at.iso8601}"
      end
    end
  end

  desc "Remove an email from the waitlist. Usage: rails waitlist:remove[email]"
  task :remove, [ :email ] => :environment do |_t, args|
    unless args[:email]
      puts "Error: Email required. Usage: rails waitlist:remove[email]"
      exit 1
    end

    entry = WaitlistEntry.find_by(email: args[:email])

    if entry.nil?
      puts "Error: Email not found on waitlist: #{args[:email]}"
      exit 1
    end

    entry.destroy!
    puts "Removed from waitlist: #{args[:email]}"
  end

  desc "Invite someone from the waitlist. Usage: rails waitlist:invite[email]"
  task :invite, [ :email ] => :environment do |_t, args|
    unless args[:email]
      puts "Error: Email required. Usage: rails waitlist:invite[email]"
      exit 1
    end

    entry = WaitlistEntry.find_by(email: args[:email])

    if entry.nil?
      puts "Error: Email not found on waitlist: #{args[:email]}"
      exit 1
    end

    invite = Invite.create!(email: args[:email], note: "From waitlist")
    entry.destroy!

    host = ENV.fetch("HOST_URL", "http://localhost:3000")
    url = "#{host}/invite/#{invite.token}"

    puts "Invite created for #{args[:email]}!"
    puts "  Link: #{url}"
    puts ""
    puts "(They have been removed from the waitlist)"
  end
end

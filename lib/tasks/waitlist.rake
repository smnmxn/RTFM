namespace :waitlist do
  desc "List all waitlist entries"
  task list: :environment do
    entries = WaitlistEntry.order(created_at: :desc)

    completed = entries.completed.count
    incomplete = entries.incomplete.count

    puts "=== Waitlist (#{entries.count} entries: #{completed} completed, #{incomplete} incomplete) ==="
    if entries.any?
      entries.each do |entry|
        status = entry.questions_completed_at ? "[completed]" : "[incomplete]"
        answers = [ entry.platform_type, entry.repo_structure, entry.vcs_provider, entry.workflow, entry.user_base ].compact.join(", ")
        answers = answers.empty? ? "" : " - #{answers}"
        puts "  #{status} #{entry.email} (joined #{entry.created_at.strftime('%Y-%m-%d %H:%M')})#{answers}"
      end
    else
      puts "  (empty)"
    end
  end

  desc "Show detailed info for a waitlist entry. Usage: rails waitlist:show[email]"
  task :show, [ :email ] => :environment do |_t, args|
    unless args[:email]
      puts "Error: Email required. Usage: rails waitlist:show[email]"
      exit 1
    end

    entry = WaitlistEntry.find_by(email: args[:email])

    if entry.nil?
      puts "Error: Email not found on waitlist: #{args[:email]}"
      exit 1
    end

    puts "=== Waitlist Entry ==="
    puts "  Email: #{entry.email}"
    puts "  Joined: #{entry.created_at.strftime('%Y-%m-%d %H:%M')}"
    puts "  Status: #{entry.questions_completed_at ? 'Completed' : 'Incomplete'}"
    puts ""
    puts "  Platform: #{entry.platform_type || '(not answered)'}"
    puts "  Repo structure: #{entry.repo_structure || '(not answered)'}"
    puts "  VCS provider: #{entry.vcs_provider || '(not answered)'}"
    puts "  Workflow: #{entry.workflow || '(not answered)'}"
    puts "  User base: #{entry.user_base || '(not answered)'}"
  end

  desc "Export waitlist entries to CSV (with all fields)"
  task export: :environment do
    entries = WaitlistEntry.order(created_at: :asc)

    if entries.empty?
      puts "Waitlist is empty."
    else
      puts "email,joined_at,completed_at,platform_type,repo_structure,vcs_provider,workflow,user_base"
      entries.each do |entry|
        completed = entry.questions_completed_at&.iso8601 || ""
        puts "#{entry.email},#{entry.created_at.iso8601},#{completed},#{entry.platform_type},#{entry.repo_structure},#{entry.vcs_provider},#{entry.workflow},#{entry.user_base}"
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

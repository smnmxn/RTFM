namespace :invites do
  desc "Create a new invite. Usage: rails invites:create[email,note]"
  task :create, [ :email, :note ] => :environment do |_t, args|
    invite = Invite.create!(
      email: args[:email],
      note: args[:note]
    )

    host = ENV.fetch("HOST_URL", "http://localhost:3000")
    url = "#{host}/invite/#{invite.token}"

    puts "Invite created!"
    puts "  Token: #{invite.token}"
    puts "  Email: #{invite.email || '(none)'}"
    puts "  Note:  #{invite.note || '(none)'}"
    puts ""
    puts "  Link: #{url}"
  end

  desc "List all invites"
  task list: :environment do
    available = Invite.available.order(created_at: :desc)
    used = Invite.used.order(used_at: :desc).limit(10)

    puts "=== Available Invites (#{available.count}) ==="
    if available.any?
      available.each do |invite|
        puts "  #{invite.token}"
        puts "    Email: #{invite.email || '(none)'}"
        puts "    Note:  #{invite.note || '(none)'}"
        puts "    Created: #{invite.created_at.strftime('%Y-%m-%d %H:%M')}"
        puts ""
      end
    else
      puts "  (none)"
    end

    puts ""
    puts "=== Recently Used Invites (showing up to 10) ==="
    if used.any?
      used.each do |invite|
        puts "  #{invite.token}"
        puts "    Email: #{invite.email || '(none)'}"
        puts "    Redeemed by: #{invite.user&.email || invite.user&.github_username || '(unknown)'}"
        puts "    Used at: #{invite.used_at.strftime('%Y-%m-%d %H:%M')}"
        puts ""
      end
    else
      puts "  (none)"
    end
  end

  desc "Revoke an unused invite. Usage: rails invites:revoke[token]"
  task :revoke, [ :token ] => :environment do |_t, args|
    unless args[:token]
      puts "Error: Token required. Usage: rails invites:revoke[token]"
      exit 1
    end

    invite = Invite.find_by(token: args[:token])

    if invite.nil?
      puts "Error: Invite not found with token: #{args[:token]}"
      exit 1
    end

    if invite.used?
      puts "Error: Cannot revoke an invite that has already been used."
      puts "  Redeemed by: #{invite.user&.email || invite.user&.github_username}"
      puts "  Used at: #{invite.used_at.strftime('%Y-%m-%d %H:%M')}"
      exit 1
    end

    invite.destroy!
    puts "Invite revoked successfully."
    puts "  Token: #{args[:token]}"
    puts "  Email: #{invite.email || '(none)'}"
  end
end

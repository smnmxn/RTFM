# frozen_string_literal: true

namespace :claude do
  desc "Test Claude authentication in Docker container"
  task test_auth: :environment do
    require "open3"

    puts "Testing Claude authentication..."
    puts "USE_CLAUDE_MAX: #{ENV['USE_CLAUDE_MAX'].present? ? 'enabled' : 'disabled'}"
    puts "Environment: #{Rails.env}"
    puts

    # Build auth args using the same logic as the jobs
    if ENV["CLAUDE_CODE_OAUTH_TOKEN"].present?
      auth_args = ["-e", "CLAUDE_CODE_OAUTH_TOKEN=#{ENV['CLAUDE_CODE_OAUTH_TOKEN']}"]
      puts "Auth method: CLAUDE_CODE_OAUTH_TOKEN (Max subscription)"
    elsif ENV["ANTHROPIC_API_KEY"].present?
      auth_args = ["-e", "ANTHROPIC_API_KEY=#{ENV['ANTHROPIC_API_KEY']}"]
      puts "Auth method: ANTHROPIC_API_KEY"
    else
      puts "ERROR: Neither CLAUDE_CODE_OAUTH_TOKEN nor ANTHROPIC_API_KEY is set"
      exit 1
    end

    puts

    # Check if Docker image exists
    stdout, _, status = Open3.capture3("docker", "images", "-q", "rtfm/claude-analyzer:latest")
    if stdout.strip.empty?
      puts "Building Docker image first..."
      dockerfile_path = Rails.root.join("docker", "claude-analyzer")
      _, stderr, status = Open3.capture3("docker", "build", "-t", "rtfm/claude-analyzer:latest", dockerfile_path.to_s)
      unless status.success?
        puts "ERROR: Failed to build Docker image: #{stderr}"
        exit 1
      end
    end

    # First, check which env vars are actually set in the container
    puts "Checking env vars in container..."
    check_cmd = [
      "docker", "run",
      "--rm",
      *auth_args,
      "--network", "host",
      "--entrypoint", "/bin/bash",
      "rtfm/claude-analyzer:latest",
      "-c", "echo 'CLAUDE_CODE_OAUTH_TOKEN set:' ${CLAUDE_CODE_OAUTH_TOKEN:+YES}${CLAUDE_CODE_OAUTH_TOKEN:-NO}; echo 'ANTHROPIC_API_KEY set:' ${ANTHROPIC_API_KEY:+YES}${ANTHROPIC_API_KEY:-NO}; echo '~/.claude/:'; ls -la ~/.claude/ 2>/dev/null || echo 'not found'; echo '~/.claude.json:'; cat ~/.claude.json 2>/dev/null || echo 'not found'"
    ]
    env_stdout, _, _ = Open3.capture3(*check_cmd)
    puts env_stdout
    puts

    # Run a simple Claude command to test auth
    cmd = [
      "docker", "run",
      "--rm",
      *auth_args,
      "--network", "host",
      "--entrypoint", "claude",
      "rtfm/claude-analyzer:latest",
      "-p", "--output-format", "json", "--max-turns", "1",
      "Reply with exactly: AUTH_SUCCESS"
    ]

    puts "Running test command..."
    puts

    stdout, stderr, status = Open3.capture3(*cmd)

    if status.success?
      # Parse JSON output to get the result
      begin
        result = JSON.parse(stdout)
        response = result["result"] || ""
        if response.include?("AUTH_SUCCESS")
          puts "SUCCESS: Claude authentication working"
          puts "Response: #{response}"

          # Show usage info if available
          usage = result["usage"] || {}
          puts
          puts "Usage info:"
          puts "  Cost: $#{result['total_cost_usd']}"
          puts "  Duration: #{result['duration_ms']}ms"
          puts "  Service tier: #{usage['service_tier'] || 'not reported'}"
          puts "  Input tokens: #{usage['input_tokens']}"
          puts "  Output tokens: #{usage['output_tokens']}"
        else
          puts "WARNING: Got response but not expected output"
          puts "Response: #{response}"
        end
      rescue JSON::ParserError
        puts "WARNING: Could not parse JSON output"
        puts "Raw output: #{stdout[0..500]}"
      end
    else
      puts "FAILED: Claude authentication failed"
      puts
      puts "Exit code: #{status.exitstatus}"
      puts "Stderr: #{stderr}" if stderr.present?
      puts "Stdout: #{stdout[0..500]}" if stdout.present?
      exit 1
    end
  end
end

namespace :test do
  desc "Run E2E tests with Playwright"
  task e2e: :environment do
    test_files = Dir[Rails.root.join("test/e2e/**/*_test.rb")]

    if test_files.empty?
      puts "No E2E test files found in test/e2e/"
      exit 0
    end

    puts "Running #{test_files.size} E2E test file(s)..."
    puts "HEADLESS=#{ENV['HEADLESS'] || 'true'}"
    puts "SLOW_MO=#{ENV['SLOW_MO'] || '0'}ms"
    puts

    # Use bin/rails test with the E2E test files
    test_paths = test_files.join(" ")
    system("bin/rails test #{test_paths}")
    exit($?.exitstatus)
  end
end

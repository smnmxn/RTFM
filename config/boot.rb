ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.

# Load environment variables from .env file in development/test
if %w[development test].include?(ENV.fetch("RAILS_ENV", "development"))
  require "dotenv"
  Dotenv.load
end

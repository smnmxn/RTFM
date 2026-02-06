require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use Redis for caching
  config.cache_store = [ :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") } ]

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :sidekiq

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "app.#{ENV.fetch("BASE_DOMAIN", "supportpages.io")}" }
  config.action_mailer.asset_host = "https://app.#{ENV.fetch("BASE_DOMAIN", "supportpages.io")}"

  # Postmark email delivery
  config.action_mailer.delivery_method = :postmark
  config.action_mailer.postmark_settings = { api_token: ENV["POSTMARK_API_TOKEN"] }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Subdomain support for public help centres
  config.x.base_domain = ENV.fetch("BASE_DOMAIN", "supportpages.io")

  # Enable DNS rebinding protection and other `Host` header attacks.
  # Dynamically configure hosts based on BASE_DOMAIN to support subdomains and custom domains
  if ENV["BASE_DOMAIN"].present?
    config.hosts = ->(host) {
      base_domain = ENV["BASE_DOMAIN"]
      # Allow base domain and all subdomains
      return true if host == base_domain
      return true if host.end_with?(".#{base_domain}")
      # Allow verified custom domains
      Project.exists?(custom_domain: host.downcase, custom_domain_status: "active")
    }
  end

  # Skip DNS rebinding protection for the default health check endpoint.
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # Action Cable: Allow WebSocket connections from base domain, subdomains, and custom domains
  # This is required for Turbo Streams to work on Help Centre pages (e.g., streaming AI responses)
  config.action_cable.allowed_request_origins = ->(origin) {
    return false if origin.blank?

    begin
      uri = URI.parse(origin)
      host = uri.host&.downcase
      return false if host.blank?

      base_domain = ENV["BASE_DOMAIN"]

      # Allow base domain and all subdomains
      return true if host == base_domain
      return true if host.end_with?(".#{base_domain}")

      # Allow verified custom domains
      Project.exists?(custom_domain: host, custom_domain_status: "active")
    rescue URI::InvalidURIError
      false
    end
  }
end

Rollbar.configure do |config|
  config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
  config.enabled = Rails.env.production? || Rails.env.staging?
  config.environment = Rails.env

  # Filter sensitive parameters (inherits from Rails)
  config.scrub_fields |= [:password, :secret, :token, :_key, :access_token, :github_token]

  # Add person tracking for logged-in users
  config.person_method = "current_user"
  config.person_id_method = "id"
  config.person_username_method = "email"
  config.person_email_method = "email"
end

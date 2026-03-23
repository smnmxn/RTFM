Rollbar.configure do |config|
  config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
  config.enabled = Rails.env.production? || Rails.env.staging?
  config.environment = Rails.env

  # Filter sensitive parameters (inherits from Rails)
  config.scrub_fields |= [
    :password, :secret, :token, :_key, :access_token, :github_token,
    :private_key, :oauth_token, :stripe_signing_secret, :api_key, :api_token
  ]

  # Suppress 404-type noise
  config.exception_level_filters.merge!(
    "ActionController::RoutingError" => "ignore",
    "ActiveRecord::RecordNotFound" => "ignore"
  )

  # Add person tracking for logged-in users
  config.person_method = "current_user"
  config.person_id_method = "id"
  config.person_username_method = "email"
  config.person_email_method = "email"
end

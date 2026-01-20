# Share session cookie across all subdomains
Rails.application.config.session_store :cookie_store,
  key: "_rtfm_session",
  domain: :all,
  tld_length: 2

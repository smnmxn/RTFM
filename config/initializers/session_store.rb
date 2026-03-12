# Share session cookie across all subdomains
# SameSite=None is required for Apple Sign-in (Apple POSTs the callback cross-site,
# so the browser won't send a Lax cookie). Requires Secure, which is set when behind TLS.
session_options = {
  key: "_rtfm_session",
  domain: :all,
  tld_length: 2
}

if ENV["BEHIND_TLS_PROXY"] == "true" || Rails.env.production?
  session_options[:same_site] = :none
  session_options[:secure] = true
end

Rails.application.config.session_store :cookie_store, **session_options

# frozen_string_literal: true

# Test-only session helper that allows E2E tests to bypass OAuth authentication.
# This is necessary because OmniAuth mocks set in the test process are not
# shared with the Puma server thread running in E2E tests.
#
# IMPORTANT: This concern is only active in the test environment.
module TestSessionHelper
  extend ActiveSupport::Concern

  included do
    if Rails.env.test?
      skip_before_action :require_authentication, only: [ :test_login ], raise: false
    end
  end

  # POST /test/login/:user_id
  # Establishes a session for the given user without going through OAuth.
  # Only available in test environment.
  #
  # Accepts optional redirect_to parameter to redirect after login.
  def test_login
    return head :not_found unless Rails.env.test?

    user = User.find_by(id: params[:user_id])
    return head :not_found unless user

    session[:user_id] = user.id

    # If redirect_to is specified, redirect there; otherwise return 200 OK
    if params[:redirect_to].present?
      redirect_to params[:redirect_to], allow_other_host: true
    else
      head :ok
    end
  end
end

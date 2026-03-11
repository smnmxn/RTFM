class User < ApplicationRecord
  include Billable

  has_secure_password validations: false

  pay_customer default_payment_processor: :stripe

  has_many :projects, dependent: :destroy
  has_many :github_app_installations, dependent: :nullify
  has_many :pending_notifications, dependent: :destroy
  has_many :user_identities, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :github_uid, uniqueness: true, allow_nil: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  def admin?
    admin
  end

  # Onboarding helpers
  def needs_onboarding?
    projects.empty?
  end

  def onboarding_in_progress?
    projects.onboarding_incomplete.exists?
  end

  def current_onboarding_project
    projects.onboarding_incomplete.first
  end

  # Check if user has an active ActionCable connection via Redis presence key
  def online?
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    redis.exists?("user:#{id}:online")
  end

  # Notification preferences with defaults
  DEFAULT_NOTIFICATION_PREFERENCES = {
    "email_notifications_enabled" => true,
    "email_events" => {
      "analysis_complete" => true,
      "sections_suggested" => true,
      "recommendations_generated" => true,
      "article_generated" => true,
      "pr_analyzed" => true,
      "commit_analyzed" => true,
      "css_generated" => true,
      "article_updates_checked" => true
    }
  }.freeze

  def effective_notification_preferences
    DEFAULT_NOTIFICATION_PREFERENCES.deep_merge(notification_preferences || {})
  end

  def email_notifications_enabled?
    effective_notification_preferences["email_notifications_enabled"]
  end

  def email_event_enabled?(event_type)
    return false unless email_notifications_enabled?
    effective_notification_preferences.dig("email_events", event_type.to_s) != false
  end

  # Returns existing user or nil (does NOT create)
  def self.find_from_omniauth(auth)
    # 1. Find by identity (provider + uid)
    identity = UserIdentity.find_by(provider: auth.provider, uid: auth.uid)
    if identity
      identity.update!(token: auth.credentials&.token)
      return identity.user
    end

    # 2. Find by email (auto-link)
    email = auth.info.email
    user = find_by(email: email) if email.present?
    if user
      user.user_identities.create!(
        provider: auth.provider, uid: auth.uid,
        token: auth.credentials&.token,
        auth_data: { username: auth.info.nickname }.compact
      )
      return user
    end

    nil
  end

  # Create new user + identity (called after invite gate passes)
  def self.create_from_omniauth!(auth)
    user = create!(email: auth.info.email, name: auth.info.name)
    user.user_identities.create!(
      provider: auth.provider, uid: auth.uid,
      token: auth.credentials&.token,
      auth_data: { username: auth.info.nickname }.compact
    )
    # Backfill legacy github columns for compatibility
    if auth.provider == "github"
      user.update_columns(
        github_uid: auth.uid,
        github_token: auth.credentials&.token,
        github_username: auth.info.nickname
      )
    end
    user
  end

  # Legacy method — kept for backward compatibility with existing code
  def self.find_or_create_from_omniauth(auth)
    user = find_from_omniauth(auth)
    return user if user

    create_from_omniauth!(auth)
  end
end

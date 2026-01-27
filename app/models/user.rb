class User < ApplicationRecord
  has_many :projects, dependent: :destroy
  has_many :github_app_installations, dependent: :nullify
  has_many :pending_notifications, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :github_uid, uniqueness: true, allow_nil: true

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

  def self.find_or_create_from_omniauth(auth)
    user = find_by(github_uid: auth.uid)

    if user
      user.update!(
        github_token: auth.credentials.token,
        github_username: auth.info.nickname,
        name: auth.info.name,
        email: auth.info.email
      )
      user
    else
      create!(
        github_uid: auth.uid,
        github_token: auth.credentials.token,
        github_username: auth.info.nickname,
        name: auth.info.name,
        email: auth.info.email
      )
    end
  end
end

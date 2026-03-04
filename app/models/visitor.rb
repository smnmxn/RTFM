class Visitor < ApplicationRecord
  has_many :analytics_events, primary_key: :visitor_id, foreign_key: :visitor_id

  validates :visitor_id, presence: true, uniqueness: true
  validates :first_seen_at, presence: true
  validates :last_seen_at, presence: true

  # Scopes for analysis
  scope :returning, -> { where("total_page_views > 1") }
  scope :new_visitors, -> { where(total_page_views: 1) }
  scope :active_since, ->(date) { where("last_seen_at >= ?", date) }
  scope :from_source, ->(source) { where(utm_source: source) }
  scope :identified, -> { where.not(email: nil) }
  scope :anonymous, -> { where(email: nil) }

  # Update visitor activity
  def record_activity!(event_type:, ip_address: nil, user_agent: nil, device_type: nil, browser_family: nil, os_family: nil)
    increment!(:total_events)
    increment!(:total_page_views) if event_type == "page_view"

    updates = { last_seen_at: Time.current }
    updates[:last_ip_address] = ip_address if ip_address.present?
    updates[:last_user_agent] = user_agent if user_agent.present?
    updates[:device_type] = device_type if device_type.present?
    updates[:browser_family] = browser_family if browser_family.present?
    updates[:os_family] = os_family if os_family.present?

    update!(updates)
  end

  # Check if this is a returning visitor
  def returning_visitor?
    total_page_views > 1
  end

  # Get visitor journey
  def journey
    analytics_events.page_views.order(:created_at)
  end

  # Identify visitor with email/name
  def identify!(email:, name: nil, user_id: nil)
    return if self.email.present? && self.email == email # Already identified

    update!(
      email: email,
      name: name || self.name,
      user_id: user_id || self.user_id,
      identified_at: identified_at || Time.current
    )
  end

  # Check if visitor has been identified
  def identified?
    email.present?
  end

  # Check if visitor converted to user
  def converted?
    user_id.present?
  end
end

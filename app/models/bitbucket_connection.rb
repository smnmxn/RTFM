class BitbucketConnection < ApplicationRecord
  belongs_to :user

  validates :workspace_slug, presence: true, uniqueness: { scope: :user_id }
  validates :access_token, presence: true
  validates :refresh_token, presence: true
  validates :token_expires_at, presence: true

  scope :active, -> { where(suspended_at: nil) }
  scope :suspended, -> { where.not(suspended_at: nil) }
  scope :for_user, ->(user) { where(user: user) }

  def token_expired?
    token_expires_at <= 5.minutes.from_now
  end

  def active?
    suspended_at.nil?
  end
end

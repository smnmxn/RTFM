class Invite < ApplicationRecord
  belongs_to :user, optional: true

  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :available, -> { where(used_at: nil) }
  scope :used, -> { where.not(used_at: nil) }

  def available?
    used_at.nil?
  end

  def used?
    used_at.present?
  end

  def redeem!(user)
    update!(user: user, used_at: Time.current)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end

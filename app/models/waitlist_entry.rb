class WaitlistEntry < ApplicationRecord
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  before_create :generate_token

  scope :completed, -> { where.not(questions_completed_at: nil) }
  scope :incomplete, -> { where(questions_completed_at: nil) }

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end
end

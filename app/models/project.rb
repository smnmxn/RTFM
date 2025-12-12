class Project < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :user
  has_many :updates, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :recommendations, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :github_repo, presence: true,
                          format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be in 'owner/repo' format" },
                          uniqueness: { scope: :user_id, message: "is already connected" }

  before_validation :generate_slug, on: :create
  before_create :generate_webhook_secret

  def verify_webhook_signature(payload, signature)
    return false if webhook_secret.blank? || signature.blank?

    expected_signature = "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      webhook_secret,
      payload
    )

    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  private

  def generate_slug
    return if slug.present? || name.blank?
    self.slug = name.parameterize
  end

  def generate_webhook_secret
    self.webhook_secret ||= SecureRandom.hex(32)
  end
end

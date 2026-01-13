class Project < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :user
  has_many :updates, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :recommendations, dependent: :destroy
  has_many :sections, dependent: :destroy

  # User-provided context (collected during onboarding)
  store :user_context, accessors: [
    :target_audience,
    :industry,
    :documentation_goals,  # Array
    :tone_preference,
    :product_stage
  ], coder: JSON

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :github_repo, presence: true,
                          format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be in 'owner/repo' format" },
                          uniqueness: { scope: :user_id, message: "is already connected" }

  before_validation :generate_slug, on: :create
  before_create :generate_webhook_secret

  # Onboarding
  ONBOARDING_STEPS = %w[repository analyze sections].freeze

  scope :onboarding_incomplete, -> { where.not(onboarding_step: [ nil, "complete" ]) }

  def in_onboarding?
    onboarding_step.present? && onboarding_step != "complete"
  end

  def onboarding_complete?
    onboarding_step == "complete" || onboarding_step.nil?
  end

  def advance_onboarding!(next_step)
    update!(onboarding_step: next_step)
  end

  def onboarding_step_number
    ONBOARDING_STEPS.index(onboarding_step)&.+(1) || 0
  end

  # Job status tracking
  def sections_being_generated?
    sections_generation_status == "running"
  end

  def sections_generation_complete?
    sections_generation_status == "completed"
  end

  def sections_recommendations_running_count
    sections.accepted.where(recommendations_status: "running").count
  end

  def sections_recommendations_complete_count
    sections.accepted.where(recommendations_status: "completed").count
  end

  def all_recommendations_generated?
    return true if sections.accepted.empty?
    sections.accepted.where.not(recommendations_status: "completed").empty?
  end

  def recommendations_generation_progress
    total = sections.accepted.count
    done = sections_recommendations_complete_count
    { done: done, total: total, percent: total > 0 ? (done * 100 / total) : 0 }
  end

  # Article review tracking
  def all_articles_generated?
    articles.where(generation_status: [ :generation_pending, :generation_running ]).empty?
  end

  def all_articles_reviewed?
    return true if articles.empty?
    articles.where(review_status: :unreviewed).empty?
  end

  def articles_review_progress
    total = articles.where(generation_status: :generation_completed).count
    reviewed = articles.where.not(review_status: :unreviewed).count
    { done: reviewed, total: total, percent: total > 0 ? (reviewed * 100 / total) : 0 }
  end

  def approved_articles
    articles.where(review_status: :approved)
  end

  def complete_onboarding!
    update!(onboarding_step: nil)
  end

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

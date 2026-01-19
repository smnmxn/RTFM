class Project < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :user
  belongs_to :github_app_installation, optional: true

  # Turbo refresh broadcasts - auto-refresh all subscribed streams on any update
  after_update_commit :broadcast_refreshes
  has_many :updates, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :recommendations, dependent: :destroy
  has_many :sections, dependent: :destroy

  # Logo upload via Active Storage
  has_one_attached :logo

  # User-provided context (collected during onboarding)
  store :user_context, accessors: [
    :target_audience,
    :industry,
    :documentation_goals,  # Array
    :tone_preference,
    :product_stage
  ], coder: JSON

  # Help Centre branding settings
  store :branding, accessors: [
    :primary_color,
    :accent_color,
    :title_text_color,
    :help_centre_title,
    :help_centre_tagline
  ], coder: JSON

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :github_repo, presence: true,
                          format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be in 'owner/repo' format" },
                          uniqueness: { scope: :user_id, message: "is already connected" }

  # Branding validations
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :accent_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :title_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true

  before_validation :generate_slug, on: :create

  # Onboarding
  ONBOARDING_STEPS = %w[repository analyze sections generating].freeze

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

  def github_client
    github_app_installation&.client
  end

  # Branding helper methods with defaults
  def primary_color_or_default
    primary_color.presence || "#4f46e5"
  end

  def accent_color_or_default
    accent_color.presence || "#7c3aed"
  end

  def title_text_color_or_default
    title_text_color.presence || "#ffffff"
  end

  def help_centre_title_or_default
    help_centre_title.presence || "Help Centre"
  end

  def help_centre_tagline_or_default
    help_centre_tagline.presence || "How can we help you?"
  end

  private

  def generate_slug
    return if slug.present? || name.blank?
    self.slug = name.parameterize
  end

  def broadcast_refreshes
    return unless status_fields_changed?

    Turbo::StreamsChannel.broadcast_refresh_to([self, :onboarding])
    Turbo::StreamsChannel.broadcast_refresh_to([self, :analysis])
    Turbo::StreamsChannel.broadcast_refresh_to([self, :updates])
    Turbo::StreamsChannel.broadcast_refresh_to([self, :inbox])
  end

  def status_fields_changed?
    saved_change_to_analysis_status? ||
      saved_change_to_onboarding_step? ||
      saved_change_to_sections_generation_status?
  end
end

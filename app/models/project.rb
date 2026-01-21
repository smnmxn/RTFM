class Project < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :user

  def to_param
    slug
  end
  belongs_to :github_app_installation, optional: true

  # Turbo refresh broadcasts - auto-refresh all subscribed streams on any update
  after_update_commit :broadcast_refreshes
  has_many :updates, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :recommendations, dependent: :destroy
  has_many :sections, dependent: :destroy
  has_many :claude_usages, dependent: :destroy

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

  # AI settings
  store :ai_settings, accessors: [
    :claude_model
  ], coder: JSON

  CLAUDE_MODELS = [
    [ "Claude Opus 4.5 (Most capable)", "claude-opus-4-5" ],
    [ "Claude Sonnet 4.5 (Balanced)", "claude-sonnet-4-5" ],
    [ "Claude Haiku 4.5 (Fastest)", "claude-haiku-4-5" ]
  ].freeze

  DEFAULT_CLAUDE_MODEL = "claude-sonnet-4-5".freeze

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  validates :github_repo, presence: true,
                          format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be in 'owner/repo' format" },
                          uniqueness: { scope: :user_id, message: "is already connected" }

  # Branding validations
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :accent_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :title_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true

  # Subdomain validations
  RESERVED_SUBDOMAINS = %w[
    www api admin app mail smtp ftp cdn assets static
    help support docs blog status dashboard
    dev staging test demo preview sandbox
    login signin signup register logout signout auth oauth sso
    account profile settings preferences user users me
    billing payment payments subscribe subscription pricing plans
    home index about contact terms privacy legal security
    download downloads install setup update updates
    news newsletter announcements
    search feedback report reports analytics metrics
    embed widget widgets integration integrations
    graphql rest webhook webhooks callback callbacks
    internal system root null undefined localhost
  ].freeze

  validates :subdomain,
    uniqueness: true,
    allow_blank: true,
    length: { minimum: 3, maximum: 63 },
    format: {
      with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?\z/,
      message: "only allows lowercase letters, numbers, and hyphens (cannot start or end with hyphen)"
    }

  validate :subdomain_not_reserved
  validate :subdomain_not_conflicting_with_slugs
  validate :slug_not_conflicting_with_subdomains

  before_validation :generate_slug, on: :create

  # Onboarding
  ONBOARDING_STEPS = %w[basics repository analyze sections generating].freeze

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
    step_index = ONBOARDING_STEPS.index(onboarding_step)
    return 0 unless step_index
    # Map to UI steps: 1=Setup, 2=Connect, 3=Analyze, 4=Review (sections+generating)
    [ step_index + 1, 4 ].min
  end

  # Job status tracking
  def sections_being_generated?
    sections_generation_status.in?(%w[pending running])
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

  # AI settings helper methods
  def claude_model_id
    claude_model.presence || DEFAULT_CLAUDE_MODEL
  end

  # Subdomain helper methods
  def effective_subdomain
    subdomain.presence || slug
  end

  def self.find_by_subdomain!(subdomain)
    find_by!(subdomain: subdomain)
  end

  private

  def generate_slug
    return if slug.present? || name.blank?
    self.slug = name.parameterize
  end

  def broadcast_refreshes
    return unless status_fields_changed?

    Rails.logger.info "[Project#broadcast_refreshes] Broadcasting refresh for project #{id}"
    Rails.logger.info "[Project#broadcast_refreshes] Changed: analysis_status=#{saved_change_to_analysis_status?}"
    Turbo::StreamsChannel.broadcast_refresh_to([self, :onboarding])
    Turbo::StreamsChannel.broadcast_refresh_to([self, :analysis])
    Turbo::StreamsChannel.broadcast_refresh_to([self, :updates])
    Turbo::StreamsChannel.broadcast_refresh_to([self, :inbox])
  end

  def status_fields_changed?
    # Note: All status fields are excluded because the jobs handle their own
    # targeted broadcasts. Including them here causes race conditions where
    # full page refreshes happen and questions disappear mid-answer.
    # The jobs use broadcast_update_to for targeted partial updates instead.
    false
  end

  def subdomain_not_reserved
    return if subdomain.blank?
    if RESERVED_SUBDOMAINS.include?(subdomain.downcase)
      errors.add(:subdomain, "is reserved and cannot be used")
    end
  end

  def subdomain_not_conflicting_with_slugs
    return if subdomain.blank?
    if Project.where.not(id: id).exists?(slug: subdomain)
      errors.add(:subdomain, "conflicts with an existing project URL")
    end
  end

  def slug_not_conflicting_with_subdomains
    return if slug.blank?
    if Project.where.not(id: id).exists?(subdomain: slug)
      errors.add(:slug, "conflicts with an existing subdomain")
    end
  end
end

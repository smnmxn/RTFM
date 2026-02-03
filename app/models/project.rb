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
  has_many :project_repositories, dependent: :destroy
  has_many :article_update_checks, dependent: :destroy
  has_many :pending_notifications, dependent: :destroy

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
    :help_centre_tagline,
    :support_email,
    :support_phone,
    :dark_mode
  ], coder: JSON

  # AI settings
  store :ai_settings, accessors: [
    :claude_model,
    :claude_max_turns,
    :update_strategy
  ], coder: JSON

  CLAUDE_MODELS = [
    [ "Claude Opus 4.5 (Most capable)", "claude-opus-4-5" ],
    [ "Claude Sonnet 4.5 (Balanced)", "claude-sonnet-4-5" ],
    [ "Claude Haiku 4.5 (Fastest)", "claude-haiku-4-5" ]
  ].freeze

  CLAUDE_MAX_TURNS_OPTIONS = [
    [ "5 turns (Fastest)", 5 ],
    [ "10 turns (Balanced)", 10 ],
    [ "15 turns (Default)", 15 ],
    [ "25 turns (Thorough)", 25 ],
    [ "Unlimited", 0 ]
  ].freeze

  UPDATE_STRATEGIES = [
    [ "On every pull request", "pull_request", "Get recommendations as soon as a PR is merged. Best for staying on top of documentation in real time." ],
    [ "Once a week", "weekly", "Collect all merged PRs and check for recommendations every Monday morning. Good for busy repos where real-time would be noisy." ],
    [ "Manually", "manual", "Only check when you click the Analyze button in Code History. Nothing runs automatically." ]
  ].freeze

  DEFAULT_UPDATE_STRATEGY = "pull_request".freeze
  DEFAULT_CLAUDE_MODEL = "claude-sonnet-4-5".freeze
  DEFAULT_CLAUDE_MAX_TURNS = 15

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }
  # github_repo is now optional - repos are stored in project_repositories table
  # Keep validation for backwards compatibility during migration
  validates :github_repo, format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be in 'owner/repo' format" },
                          allow_blank: true

  # Branding validations
  validates :primary_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :accent_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :title_text_color, format: { with: /\A#[0-9a-fA-F]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  validates :support_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validates :support_phone, length: { maximum: 30 }, allow_blank: true

  # Custom domain validations
  validates :custom_domain,
    uniqueness: true,
    allow_blank: true,
    length: { maximum: 255 },
    format: {
      with: /\A[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+\z/i,
      message: "must be a valid domain name (e.g., help.example.com)"
    }

  validate :custom_domain_not_internal
  validate :custom_domain_not_base_domain

  # Subdomain validations
  RESERVED_SUBDOMAINS = %w[
    www api admin app mail smtp ftp cdn assets static
    host fallback support docs blog status dashboard
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
  before_validation :normalize_custom_domain
  after_save :handle_custom_domain_change

  # Onboarding
  ONBOARDING_STEPS = %w[repository setup analyze sections generating].freeze

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
    # Map to UI steps: 1=Connect, 2=Setup, 3=Analyze, 4=Review (sections+generating)
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

  def has_running_jobs?
    analysis_status == "running" ||
      sections_generation_status.in?(%w[pending running]) ||
      sections.where(recommendations_status: "running").exists? ||
      articles.where(generation_status: [ :generation_pending, :generation_running ]).exists?
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
    # Use primary repository's installation client, fall back to project's installation
    primary_repository&.client || github_app_installation&.client
  end

  # Multi-repository support methods

  # Returns the primary github_repo name (for backwards compatibility)
  # First checks project_repositories, falls back to legacy github_repo column
  def primary_github_repo
    primary_repository&.github_repo || read_attribute(:github_repo)
  end

  # Returns the primary repository, or the first one if none marked primary
  def primary_repository
    project_repositories.primary.first || project_repositories.first
  end

  # Returns an array of all connected repo names (owner/repo format)
  def github_repos
    project_repositories.pluck(:github_repo)
  end

  # Check if this project has multiple repositories
  def multi_repo?
    project_repositories.count > 1
  end

  # Build the repositories data structure for Docker analysis
  # Returns array of hashes with repo, directory, and installation_id
  def repositories_for_analysis
    project_repositories.map do |pr|
      {
        repo: pr.github_repo,
        directory: pr.clone_directory_name,
        installation_id: pr.github_installation_id
      }
    end
  end

  # Get repository relationships from analysis metadata (for multi-repo projects)
  def repository_relationships
    analysis_metadata&.dig("repository_relationships")
  end

  # Count commits ahead of baseline (cached for 5 minutes)
  def commits_since_baseline
    return nil unless analysis_commit_sha.present?

    Rails.cache.fetch("project:#{id}:commits_since_baseline", expires_in: 5.minutes) do
      client = github_client
      return nil unless client

      comparison = client.compare(primary_github_repo, analysis_commit_sha, "HEAD")
      comparison.ahead_by
    rescue Octokit::Error => e
      Rails.logger.warn "[Project#commits_since_baseline] GitHub API error: #{e.message}"
      nil
    end
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

  def has_support_contact?
    support_email.present? || support_phone.present?
  end

  def dark_mode_enabled?
    dark_mode == true || dark_mode == "true" || dark_mode == "1"
  end

  # AI settings helper methods
  def update_strategy_value
    update_strategy.presence || DEFAULT_UPDATE_STRATEGY
  end

  def claude_model_id
    claude_model.presence || DEFAULT_CLAUDE_MODEL
  end

  def claude_max_turns_value
    turns = claude_max_turns.presence&.to_i
    turns.nil? || turns <= 0 ? DEFAULT_CLAUDE_MAX_TURNS : turns
  end

  # Returns nil for unlimited, or the max turns value
  def claude_max_turns_arg
    turns = claude_max_turns.presence&.to_i
    return nil if turns == 0  # 0 means unlimited
    turns.nil? ? DEFAULT_CLAUDE_MAX_TURNS : turns
  end

  # Subdomain helper methods
  def effective_subdomain
    subdomain.presence || slug
  end

  def self.find_by_subdomain!(subdomain)
    find_by!(subdomain: subdomain)
  end

  # Custom domain helper methods
  CUSTOM_DOMAIN_STATUSES = %w[pending verifying active failed].freeze

  def custom_domain_active?
    custom_domain.present? && custom_domain_status == "active"
  end

  def custom_domain_pending?
    custom_domain.present? && custom_domain_status == "pending"
  end

  def custom_domain_verifying?
    custom_domain.present? && custom_domain_status == "verifying"
  end

  def custom_domain_failed?
    custom_domain.present? && custom_domain_status == "failed"
  end

  def custom_domain_cname_target
    base_domain = Rails.application.config.x.base_domain&.split(":")&.first
    "#{effective_subdomain}.#{base_domain}"
  end

  def self.find_by_custom_domain(domain)
    return nil if domain.blank?
    find_by(custom_domain: domain.downcase, custom_domain_status: "active")
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
    Turbo::StreamsChannel.broadcast_refresh_to([ self, :onboarding ])
    Turbo::StreamsChannel.broadcast_refresh_to([ self, :analysis ])
    Turbo::StreamsChannel.broadcast_refresh_to([ self, :updates ])
    Turbo::StreamsChannel.broadcast_refresh_to([ self, :inbox ])
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

  def normalize_custom_domain
    return if custom_domain.blank?

    # Lowercase and strip whitespace
    self.custom_domain = custom_domain.strip.downcase

    # Remove protocol if present
    self.custom_domain = custom_domain.sub(%r{\Ahttps?://}, "")

    # Remove trailing slash/path
    self.custom_domain = custom_domain.split("/").first

    # Blank out if empty after normalization
    self.custom_domain = nil if custom_domain.blank?
  end

  def custom_domain_not_internal
    return if custom_domain.blank?

    base_domain = Rails.application.config.x.base_domain&.split(":")&.first
    return if base_domain.blank?

    if custom_domain == base_domain || custom_domain.end_with?(".#{base_domain}")
      errors.add(:custom_domain, "cannot be the application domain or a subdomain of it")
    end
  end

  def custom_domain_not_base_domain
    return if custom_domain.blank?

    # Reject common TLDs without subdomain
    if custom_domain.count(".") < 2 && !custom_domain.match?(/\A[a-z0-9-]+\.[a-z]{2,}\z/i)
      errors.add(:custom_domain, "must include a subdomain (e.g., help.example.com)")
    end
  end

  def handle_custom_domain_change
    return unless saved_change_to_custom_domain?

    old_domain, new_domain = saved_change_to_custom_domain

    # If domain was removed, clean up Cloudflare
    if old_domain.present? && new_domain.blank?
      old_cloudflare_id = custom_domain_cloudflare_id_before_last_save
      if old_cloudflare_id.present?
        RemoveCustomDomainJob.perform_later(cloudflare_id: old_cloudflare_id)
      end
      # Reset status fields (already nil since domain is blank)
      update_columns(
        custom_domain_status: nil,
        custom_domain_cloudflare_id: nil,
        custom_domain_ssl_status: nil,
        custom_domain_verified_at: nil
      )
      return
    end

    # If domain changed (not just added), remove old one from Cloudflare
    if old_domain.present? && new_domain.present? && old_domain != new_domain
      old_cloudflare_id = custom_domain_cloudflare_id_before_last_save
      if old_cloudflare_id.present?
        RemoveCustomDomainJob.perform_later(cloudflare_id: old_cloudflare_id)
      end
    end

    # If new domain was set, reset status and trigger setup
    if new_domain.present?
      update_columns(
        custom_domain_status: "pending",
        custom_domain_cloudflare_id: nil,
        custom_domain_ssl_status: nil,
        custom_domain_verified_at: nil
      )
      SetupCustomDomainJob.perform_later(project_id: id)
    end
  end
end

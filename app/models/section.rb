class Section < ApplicationRecord
  include InvalidatesHelpCentreCache

  belongs_to :project
  has_many :articles, dependent: :nullify
  has_many :recommendations, dependent: :nullify

  # Turbo refresh broadcasts
  after_commit :broadcast_refreshes, on: [ :create, :update, :destroy ]

  enum :section_type, {
    template: "template",
    ai_generated: "ai_generated",
    custom: "custom"
  }, default: :template

  enum :status, {
    pending: "pending",
    accepted: "accepted",
    rejected: "rejected"
  }, default: :accepted

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :project_id }
  validates :position, presence: true

  before_validation :generate_slug, on: :create

  scope :visible, -> { accepted.where(visible: true) }
  scope :ordered, -> { order(position: :asc) }
  scope :with_published_articles, -> { joins(:articles).where(articles: { status: :published }).distinct }

  # Template section definitions based on "Jobs to be Done" categorization
  # Icons use Heroicons names (https://heroicons.com)
  TEMPLATES = [
    {
      slug: "getting-started",
      name: "Getting Started",
      description: "Set up and configure the basics to get up and running",
      icon: "paper-airplane"
    },
    {
      slug: "daily-tasks",
      name: "Daily Tasks",
      description: "Common everyday workflows and regular operations",
      icon: "clipboard-document-list"
    },
    {
      slug: "advanced-usage",
      name: "Advanced Usage",
      description: "Power user features, customization, and integrations",
      icon: "cog-6-tooth"
    },
    {
      slug: "troubleshooting",
      name: "Troubleshooting",
      description: "Solve common problems and find answers to FAQs",
      icon: "wrench-screwdriver"
    }
  ].freeze

  # Default icon for custom sections
  DEFAULT_ICON = "document-text".freeze

  # Curated icon options for the icon picker
  ICON_OPTIONS = [
    "document-text",           # Default
    "paper-airplane",          # Getting started / Launch
    "clipboard-document-list", # Tasks
    "cog-6-tooth",             # Settings / Advanced
    "wrench-screwdriver",      # Troubleshooting
    "book-open",               # Documentation
    "code-bracket",            # API / Code
    "puzzle-piece",            # Integrations
    "shield-check",            # Security
    "chart-bar",               # Analytics
    "users",                   # Team / Users
    "credit-card",             # Billing
    # Additional icons
    "sparkles",                # New features / Highlights
    "light-bulb",              # Ideas / Tips
    "bolt",                    # Quick actions / Performance
    "globe-alt",               # Web / International
    "key",                     # Authentication / Access
    "cube",                    # Components / Modules
    "command-line",            # CLI / Terminal
    "academic-cap",            # Learning / Tutorials
    "megaphone",               # Announcements
    "calendar",                # Scheduling / Events
    "beaker",                  # Experiments / Beta
    "bell"                     # Notifications / Alerts
  ].freeze

  def self.create_templates_for(project)
    TEMPLATES.each_with_index do |template, index|
      project.sections.find_or_create_by!(slug: template[:slug]) do |section|
        section.name = template[:name]
        section.description = template[:description]
        section.icon = template[:icon]
        section.position = index
        section.section_type = :template
      end
    end
  end

  # Returns the icon name, falling back to default if not set
  def icon_name
    icon.presence || DEFAULT_ICON
  end

  def published_articles
    articles.published.order(:created_at)
  end

  def pending_recommendations
    recommendations.pending
  end

  private

  def generate_slug
    return if slug.present? || name.blank?
    self.slug = name.parameterize
  end

  def broadcast_refreshes
    # Skip onboarding broadcast during section generation - the job handles
    # its own broadcast at the end. Broadcasting here causes race conditions
    # where the page refreshes and questions disappear mid-answer.
    if project.sections_being_generated?
      Rails.logger.info "[Section#broadcast_refreshes] SKIPPING broadcast - sections being generated"
    else
      Rails.logger.info "[Section#broadcast_refreshes] Broadcasting refresh for section #{id}"
      Turbo::StreamsChannel.broadcast_refresh_to([project, :onboarding])
    end
    # Also broadcast to inbox when recommendations_status changes
    if saved_change_to_recommendations_status?
      Turbo::StreamsChannel.broadcast_refresh_to([project, :inbox])
    end
  end

  # Help Centre cache invalidation
  def project_for_cache
    project
  end

  def should_invalidate_help_centre_cache?
    # Invalidate when a section with published articles is destroyed
    return true if destroyed? && articles.published.exists?

    # Invalidate when visibility changes (may hide/show articles in help centre)
    return true if saved_change_to_visible?

    false
  end
end

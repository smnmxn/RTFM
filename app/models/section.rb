class Section < ApplicationRecord
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
      icon: "rocket-launch"
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
    Turbo::StreamsChannel.broadcast_refresh_to([project, :onboarding])
    # Also broadcast to inbox when recommendations_status changes
    if saved_change_to_recommendations_status?
      Turbo::StreamsChannel.broadcast_refresh_to([project, :inbox])
    end
  end
end

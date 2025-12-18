class Section < ApplicationRecord
  belongs_to :project
  has_many :articles, dependent: :nullify
  has_many :recommendations, dependent: :nullify

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
  TEMPLATES = [
    {
      slug: "getting-started",
      name: "Getting Started",
      description: "Set up and configure the basics to get up and running"
    },
    {
      slug: "daily-tasks",
      name: "Daily Tasks",
      description: "Common everyday workflows and regular operations"
    },
    {
      slug: "advanced-usage",
      name: "Advanced Usage",
      description: "Power user features, customization, and integrations"
    },
    {
      slug: "troubleshooting",
      name: "Troubleshooting",
      description: "Solve common problems and find answers to FAQs"
    }
  ].freeze

  def self.create_templates_for(project)
    TEMPLATES.each_with_index do |template, index|
      project.sections.find_or_create_by!(slug: template[:slug]) do |section|
        section.name = template[:name]
        section.description = template[:description]
        section.position = index
        section.section_type = :template
      end
    end
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
end

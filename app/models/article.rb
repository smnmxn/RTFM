class Article < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :project
  belongs_to :recommendation
  belongs_to :section, optional: true

  enum :status, { draft: "draft", published: "published" }, default: :draft
  enum :generation_status, {
    generation_pending: "pending",
    generation_running: "running",
    generation_completed: "completed",
    generation_failed: "failed"
  }, default: :generation_pending
  enum :review_status, {
    unreviewed: "unreviewed",
    approved: "approved",
    rejected: "rejected"
  }, default: :unreviewed

  validates :title, presence: true

  scope :published, -> { where(status: :published).order(published_at: :desc) }
  scope :drafts, -> { where(status: :draft).order(created_at: :desc) }
  scope :needs_review, -> { where(review_status: :unreviewed, generation_status: :generation_completed) }
  scope :for_help_centre, -> { approved.published }

  def publish!
    update!(status: :published, published_at: Time.current)
  end

  def unpublish!
    update!(status: :draft, published_at: nil)
  end

  def approve!
    update!(review_status: :approved, reviewed_at: Time.current)
  end

  def reject!
    update!(review_status: :rejected, reviewed_at: Time.current)
  end

  # Structured content accessors
  def structured?
    structured_content.present?
  end

  def introduction
    structured_content&.dig("introduction")
  end

  def prerequisites
    structured_content&.dig("prerequisites") || []
  end

  def steps
    structured_content&.dig("steps") || []
  end

  def tips
    structured_content&.dig("tips") || []
  end

  def summary
    structured_content&.dig("summary")
  end
end

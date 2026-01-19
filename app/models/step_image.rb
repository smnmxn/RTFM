class StepImage < ApplicationRecord
  belongs_to :article
  has_one_attached :image

  validates :step_index, presence: true
  validates :step_index, uniqueness: { scope: :article_id }
  validates :image, presence: true

  # Render status values
  RENDER_STATUS_PENDING = "pending"
  RENDER_STATUS_SUCCESS = "success"
  RENDER_STATUS_WARNING = "warning"
  RENDER_STATUS_FAILED = "failed"

  scope :with_warnings, -> { where(render_status: RENDER_STATUS_WARNING) }
  scope :failed, -> { where(render_status: RENDER_STATUS_FAILED) }

  def thumbnail
    image.variant(resize_to_limit: [ 200, 200 ])
  end

  def display
    image.variant(resize_to_limit: [ 800, 600 ])
  end

  def quality_score
    render_metadata&.dig("qualityScore", "score")
  end

  def quality_rating
    render_metadata&.dig("qualityScore", "rating")
  end

  def page_errors
    render_metadata&.dig("pageErrors") || []
  end

  def failed_resources
    render_metadata&.dig("failedResources") || []
  end

  def render_successful?
    render_status == RENDER_STATUS_SUCCESS
  end

  def render_has_warnings?
    render_status == RENDER_STATUS_WARNING
  end
end

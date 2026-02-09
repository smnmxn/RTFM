class Recommendation < ApplicationRecord
  belongs_to :project
  belongs_to :source_update, class_name: "Update", optional: true
  belongs_to :section, optional: true
  has_one :article

  # Broadcast to inbox when recommendations are created or updated
  after_commit :broadcast_to_inbox, on: [ :create, :update, :destroy ]

  enum :status, { pending: "pending", rejected: "rejected", generated: "generated" }, default: :pending

  validates :title, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :rejected, -> { where(status: :rejected) }
  scope :generated, -> { where(status: :generated) }

  def reject!
    update!(status: :rejected, rejected_at: Time.current)
  end

  def generate!
    update!(status: :generated)
  end

  include Turbo::Broadcastable

  private

  def broadcast_to_inbox
    # Skip broadcasting for generated recommendations (e.g., manually created articles)
    # These don't need to appear in the inbox
    return if generated? && previously_new_record?

    # Always replace the entire section to keep the header count accurate
    # and ensure the section renders even when transitioning from empty state
    pending_recs = project.recommendations.pending.includes(:section).order(created_at: :asc)

    broadcast_replace_to(
      [ project, :inbox ],
      target: "recommendations-section",
      partial: "projects/recommendations_section",
      locals: { pending_recommendations: pending_recs, selected_recommendation_id: nil }
    )

    # Update progress counter
    broadcast_replace_to(
      [ project, :inbox ],
      target: "inbox-progress",
      partial: "projects/inbox_progress",
      locals: { project: project }
    )

    # Update tab badge
    broadcast_replace_to(
      [ project, :inbox ],
      target: "inbox-tab-badge",
      partial: "projects/inbox_tab_badge",
      locals: { project: project }
    )

    # Keep recommendations stream refresh for other views
    Turbo::StreamsChannel.broadcast_refresh_to([ project, :recommendations ])
  end
end

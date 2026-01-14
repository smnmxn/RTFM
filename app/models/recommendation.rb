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

  private

  def broadcast_to_inbox
    Turbo::StreamsChannel.broadcast_refresh_to([project, :inbox])
    Turbo::StreamsChannel.broadcast_refresh_to([project, :recommendations])
  end
end

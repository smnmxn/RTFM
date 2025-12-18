class Recommendation < ApplicationRecord
  belongs_to :project
  belongs_to :source_update, class_name: "Update", optional: true
  belongs_to :section, optional: true
  has_one :article

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
end

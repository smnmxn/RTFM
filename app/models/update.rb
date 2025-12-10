class Update < ApplicationRecord
  belongs_to :project

  enum :status, { draft: "draft", published: "published" }, default: :draft

  validates :title, presence: true

  scope :published, -> { where(status: :published).order(published_at: :desc) }
  scope :drafts, -> { where(status: :draft).order(created_at: :desc) }

  def publish!
    update!(status: :published, published_at: Time.current)
  end
end

class Update < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :project
  has_many :recommendations, foreign_key: :source_update_id, dependent: :nullify

  enum :status, { draft: "draft", published: "published" }, default: :draft
  enum :source_type, { pull_request: "pull_request", commit: "commit" }, default: :pull_request

  validates :title, presence: true
  validates :commit_sha, presence: true, if: -> { commit? }

  scope :published, -> { where(status: :published).order(published_at: :desc) }
  scope :drafts, -> { where(status: :draft).order(created_at: :desc) }
  scope :from_pull_requests, -> { where(source_type: :pull_request) }
  scope :from_commits, -> { where(source_type: :commit) }

  def publish!
    update!(status: :published, published_at: Time.current)
  end
end

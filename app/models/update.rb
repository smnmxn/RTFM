class Update < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :project
  has_many :recommendations, foreign_key: :source_update_id, dependent: :nullify

  enum :status, { draft: "draft", published: "published" }, default: :draft
  enum :source_type, { pull_request: "pull_request", commit: "commit" }, default: :pull_request

  validates :title, presence: true
  validates :commit_sha, presence: true, if: -> { commit? }

  after_update_commit :broadcast_code_history_refresh, if: :saved_change_to_analysis_status?

  scope :published, -> { where(status: :published).order(published_at: :desc) }
  scope :drafts, -> { where(status: :draft).order(created_at: :desc) }
  scope :from_pull_requests, -> { where(source_type: :pull_request) }
  scope :from_commits, -> { where(source_type: :commit) }
  scope :analyzed, -> { where(analysis_status: "completed") }

  def self.latest_analyzed
    analyzed.order(created_at: :desc).first
  end

  def publish!
    update!(status: :published, published_at: Time.current)
  end

  def analysis_reason
    recommended_articles&.dig("no_articles_reason")
  end

  def has_recommendations?
    recommendations.any? || recommended_articles&.dig("articles")&.any?
  end

  private

  def broadcast_code_history_refresh
    project.reload
    Rails.cache.delete("project:#{project.id}:commits_since_baseline")

    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :code_history ],
      target: "code-history-timeline",
      partial: "projects/code_history_timeline_reload",
      locals: { project: project }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      [ project, :code_history ],
      target: "docs-status-banner",
      partial: "projects/docs_behind_banner",
      locals: { project: project }
    )
  end
end

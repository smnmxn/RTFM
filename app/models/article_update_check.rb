class ArticleUpdateCheck < ApplicationRecord
  belongs_to :project
  has_many :article_update_suggestions, dependent: :destroy

  enum :status, {
    pending: "pending",
    running: "running",
    completed: "completed",
    failed: "failed"
  }, default: :pending

  validates :target_commit_sha, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def articles_needing_updates
    article_update_suggestions.where(suggestion_type: :update_needed)
  end

  def new_article_suggestions
    article_update_suggestions.where(suggestion_type: :new_article)
  end

  def summary
    {
      total_suggestions: article_update_suggestions.count,
      updates_needed: articles_needing_updates.count,
      new_articles: new_article_suggestions.count,
      high_priority: article_update_suggestions.where(priority: :high).count,
      critical: article_update_suggestions.where(priority: :critical).count
    }
  end

  def duration_seconds
    return nil unless started_at && completed_at
    (completed_at - started_at).round
  end

  def short_target_sha
    target_commit_sha&.first(7)
  end

  def short_base_sha
    base_commit_sha&.first(7)
  end
end

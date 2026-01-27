class ArticleUpdateSuggestion < ApplicationRecord
  belongs_to :article_update_check
  belongs_to :article, optional: true

  enum :suggestion_type, {
    update_needed: "update_needed",
    new_article: "new_article"
  }, prefix: true

  enum :priority, {
    low: "low",
    medium: "medium",
    high: "high",
    critical: "critical"
  }, default: :medium

  enum :status, {
    pending: "pending",
    accepted: "accepted",
    dismissed: "dismissed"
  }, default: :pending, prefix: :suggestion

  validates :suggestion_type, presence: true

  scope :pending, -> { where(status: :pending) }
  scope :by_priority, -> { order(Arel.sql("CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END")) }

  def accept!
    transaction do
      update!(status: :accepted)

      # Flag existing article for regeneration with guidance
      if suggestion_type_update_needed? && article.present?
        set_article_regeneration_guidance
      end
    end
  end

  def dismiss!
    update!(status: :dismissed)
  end

  def priority_color
    case priority
    when "critical" then "red"
    when "high" then "orange"
    when "medium" then "yellow"
    when "low" then "gray"
    else "gray"
    end
  end

  def priority_badge_classes
    case priority
    when "critical"
      "bg-red-100 text-red-800"
    when "high"
      "bg-orange-100 text-orange-800"
    when "medium"
      "bg-yellow-100 text-yellow-800"
    when "low"
      "bg-gray-100 text-gray-600"
    else
      "bg-gray-100 text-gray-600"
    end
  end

  private

  def set_article_regeneration_guidance
    changes = suggested_changes || {}
    guidance_parts = []

    guidance_parts << reason if reason.present?

    if changes["update_steps"].present?
      guidance_parts << "Steps that need updating: #{changes['update_steps'].join(', ')}"
    end

    guidance_parts << "Update the introduction" if changes["update_introduction"]
    guidance_parts << "Add a new prerequisite" if changes["add_prerequisite"]
    guidance_parts << changes["notes"] if changes["notes"].present?

    if affected_files.present?
      guidance_parts << "Affected files: #{affected_files.first(5).join(', ')}"
    end

    article.update!(regeneration_guidance: guidance_parts.join("\n\n"))
  end
end

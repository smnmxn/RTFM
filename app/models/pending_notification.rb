class PendingNotification < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :event_type, presence: true
  validates :status, presence: true

  scope :for_project, ->(project) { where(project: project) }

  def detail_text
    return nil if metadata.blank?

    case event_type
    when "analysis_complete"
      count = metadata["repo_count"]
      count ? "Scanned #{count} #{"repository".pluralize(count)}" : nil
    when "sections_suggested"
      count = metadata["section_count"]
      count ? "#{count} #{"section".pluralize(count)} proposed" : nil
    when "recommendations_generated"
      count = metadata["recommendation_count"]
      section = metadata["section_name"]
      if section
        "#{count} #{"recommendation".pluralize(count.to_i)} for #{section}"
      elsif count
        "#{count} recommendations across all sections"
      end
    when "article_generated"
      metadata["article_title"]
    when "pr_analyzed"
      parts = []
      title = metadata["pr_title"]
      nr = metadata["pr_number"]
      parts << "PR ##{nr}: #{title}" if title.present?
      article_count = metadata["article_titles"]&.size
      parts << "#{article_count} #{"article".pluralize(article_count)} suggested" if article_count&.positive?
      parts.any? ? parts.join(" — ") : nil
    when "commit_analyzed"
      parts = []
      title = metadata["commit_title"]
      sha = metadata["commit_sha"]&.slice(0, 7)
      parts << "#{sha}: #{title}" if title.present?
      article_count = metadata["article_titles"]&.size
      parts << "#{article_count} #{"article".pluralize(article_count)} suggested" if article_count&.positive?
      parts.any? ? parts.join(" — ") : nil
    end
  end

  def next_step_text
    if status == "success"
      case event_type
      when "analysis_complete"
        "Your sections are being generated next."
      when "sections_suggested"
        "Review and pick the sections you want."
      when "recommendations_generated"
        "Accept the ones you like, reject the rest."
      when "article_generated"
        "Review it and publish when you're happy."
      when "pr_analyzed", "commit_analyzed"
        count = metadata&.dig("article_titles")&.size
        if count&.positive?
          "Review the suggested articles in code history."
        else
          "Check code history for details."
        end
      end
    else
      case event_type
      when "analysis_complete", "sections_suggested"
        "You can retry from project settings."
      when "article_generated"
        "You can regenerate it from the inbox."
      end
    end
  end
end

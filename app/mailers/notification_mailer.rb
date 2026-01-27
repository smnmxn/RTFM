class NotificationMailer < ApplicationMailer
  def digest(user:, project:, notifications:)
    @user = user
    @project = project
    @notifications = notifications
    @successes = notifications.select { |n| n.status == "success" }
    @failures = notifications.select { |n| n.status == "error" }
    @sent_at = Time.current
    @preview = build_preview(notifications, project)
    cta = build_cta(notifications, project)
    @cta_text = cta[:text]
    @cta_url = cta[:url]

    subject = build_subject(project, notifications)

    mail(to: user.email, subject: subject)
  end

  private

  # Priority order for smart subject lines
  CTA_PRIORITY = %w[article_generated recommendations_generated sections_suggested analysis_complete pr_analyzed commit_analyzed].freeze

  def build_subject(project, notifications)
    successes = notifications.select { |n| n.status == "success" }
    failures = notifications.select { |n| n.status == "error" }

    # Try to pick a compelling subject from the most important event
    top = CTA_PRIORITY.each do |type|
      n = successes.find { |s| s.event_type == type }
      break n if n
    end

    if top.is_a?(PendingNotification)
      headline = case top.event_type
      when "article_generated"
        "Your article is ready to review"
      when "recommendations_generated"
        count = top.metadata&.dig("recommendation_count")
        count ? "#{count} new article ideas" : "New article ideas are waiting"
      when "sections_suggested"
        "Your doc sections are ready to review"
      when "analysis_complete"
        "Your codebase analysis is complete"
      when "pr_analyzed"
        nr = top.metadata&.dig("pr_number")
        nr ? "PR ##{nr} has been reviewed" : "A pull request has been reviewed"
      when "commit_analyzed"
        sha = top.metadata&.dig("commit_sha")&.slice(0, 7)
        sha ? "Commit #{sha} has been reviewed" : "A commit has been reviewed"
      end

      extra = if failures.any?
        " (#{failures.size} #{"issue".pluralize(failures.size)})"
      elsif successes.size > 1
        " + #{successes.size - 1} more"
      end

      "#{project.name}: #{headline}#{extra}"
    elsif failures.any? && successes.any?
      "#{project.name}: #{successes.size} completed, #{failures.size} failed"
    elsif failures.any?
      "#{project.name}: #{failures.size} #{"task".pluralize(failures.size)} failed"
    else
      "#{project.name}: #{successes.size} #{"task".pluralize(successes.size)} completed"
    end
  end

  def build_cta(notifications, project)
    successes = notifications.select { |n| n.status == "success" }

    CTA_PRIORITY.each do |type|
      n = successes.find { |s| s.event_type == type }
      next unless n

      case type
      when "article_generated"
        return { text: "Review & Publish", url: n.action_url }
      when "recommendations_generated"
        return { text: "Review Recommendations", url: n.action_url }
      when "sections_suggested"
        return { text: "Choose Your Sections", url: n.action_url }
      when "pr_analyzed", "commit_analyzed"
        return { text: "View Changes", url: n.action_url }
      end
    end

    { text: "Open Project", url: "/projects/#{project.slug}" }
  end

  SAMPLE_PREVIEW = {
    type: :article,
    title: "Getting Started Guide",
    intro: "Welcome to the project. This guide walks you through setting up your development environment, installing dependencies, and running your first build. By the end, you'll have a fully working local setup ready for development...",
    url: "#"
  }.freeze

  def build_preview(notifications, project)
    sample_mode = notifications.first && !notifications.first.persisted?

    # Article preview (highest priority)
    article_notif = notifications.find { |n| n.event_type == "article_generated" && n.status == "success" }
    if article_notif
      return SAMPLE_PREVIEW if sample_mode

      article = Article.find_by(id: article_notif.metadata&.dig("article_id"))
      if article&.introduction.present?
        return { type: :article, title: article.title, intro: article.introduction.truncate(250), url: article_notif.action_url }
      end
    end

    # Recommendations preview
    recs_notif = notifications.find { |n| n.event_type == "recommendations_generated" && n.status == "success" }
    if recs_notif
      if sample_mode
        return { type: :recommendations, titles: [ "Getting Started Guide", "Authentication Setup", "API Reference" ], url: "#" }
      end

      titles = project.recommendations.pending.order(created_at: :desc).limit(3).pluck(:title)
      return { type: :recommendations, titles: titles, url: recs_notif.action_url } if titles.any?
    end

    nil
  end
end

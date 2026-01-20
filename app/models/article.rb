class Article < ApplicationRecord
  include Turbo::Broadcastable

  belongs_to :project
  belongs_to :recommendation
  belongs_to :section, optional: true
  has_many :step_images, dependent: :destroy

  # Turbo refresh broadcasts
  after_update_commit :broadcast_refreshes

  enum :status, { draft: "draft", published: "published" }, default: :draft
  enum :generation_status, {
    generation_pending: "pending",
    generation_running: "running",
    generation_completed: "completed",
    generation_failed: "failed"
  }, default: :generation_pending
  enum :review_status, {
    unreviewed: "unreviewed",
    approved: "approved",
    rejected: "rejected"
  }, default: :unreviewed

  validates :title, presence: true

  scope :published, -> { where(status: :published).order(published_at: :desc) }
  scope :drafts, -> { where(status: :draft).order(created_at: :desc) }
  scope :needs_review, -> { where(review_status: :unreviewed, generation_status: :generation_completed) }
  scope :for_help_centre, -> { approved.published }
  scope :ordered, -> { order(:position) }

  def publish!
    update!(status: :published, published_at: Time.current)
  end

  def unpublish!
    update!(status: :draft, published_at: nil)
  end

  def approve!
    update!(review_status: :approved, reviewed_at: Time.current)
  end

  def reject!
    update!(review_status: :rejected, reviewed_at: Time.current)
  end

  # Structured content accessors
  def structured?
    structured_content.present?
  end

  def introduction
    structured_content&.dig("introduction")
  end

  def prerequisites
    structured_content&.dig("prerequisites") || []
  end

  def steps
    structured_content&.dig("steps") || []
  end

  def step_image(index)
    step_images.find_by(step_index: index)
  end

  def reindex_step_images_after_removal(removed_index)
    step_images.where(step_index: removed_index).destroy_all
    step_images.where("step_index > ?", removed_index).find_each do |si|
      si.update!(step_index: si.step_index - 1)
    end
  end

  def tips
    structured_content&.dig("tips") || []
  end

  def summary
    structured_content&.dig("summary")
  end

  # Move article to a different section
  def move_to_section!(new_section)
    new_position = if new_section
      new_section.articles.for_help_centre.maximum(:position).to_i + 1
    else
      project.articles.for_help_centre.where(section: nil).maximum(:position).to_i + 1
    end
    update!(section: new_section, position: new_position)
  end

  # Create a duplicate of this article
  def duplicate!
    new_article = project.articles.create!(
      recommendation: recommendation,
      section: section,
      title: "#{title} (Copy)",
      content: content,
      structured_content: structured_content,
      status: :draft,
      generation_status: :generation_completed,
      review_status: :approved,
      position: (section&.articles&.maximum(:position).to_i || 0) + 1
    )

    step_images.each do |step_image|
      new_step_image = new_article.step_images.build(step_index: step_image.step_index)
      new_step_image.image.attach(step_image.image.blob)
      new_step_image.save!
    end

    new_article
  end

  # Reorder article within its section
  def reorder!(new_position)
    return if new_position == position

    articles_scope = section ? section.articles.for_help_centre : project.articles.for_help_centre.where(section: nil)

    if new_position > position
      # Moving down: decrement positions of articles between old and new position
      articles_scope.where("position > ? AND position <= ?", position, new_position).update_all("position = position - 1")
    else
      # Moving up: increment positions of articles between new and old position
      articles_scope.where("position >= ? AND position < ?", new_position, position).update_all("position = position + 1")
    end

    update!(position: new_position)
  end

  private

  def broadcast_refreshes
    # Only broadcast for relevant status changes
    return unless saved_change_to_generation_status? || saved_change_to_review_status?

    # Determine if article is entering inbox (wasn't unreviewed before, now is)
    entering_inbox = saved_change_to_review_status? &&
                     review_status_before_last_save != "unreviewed" &&
                     unreviewed?

    # For inbox: add or update the article row
    if unreviewed? && (generation_running? || generation_completed?)
      if entering_inbox
        # Article is newly entering inbox (e.g., regeneration from Articles tab)
        # Use full refresh since we may need to update empty state, section headers, etc.
        Turbo::StreamsChannel.broadcast_refresh_to([project, :inbox])
      else
        # Article already in inbox - just update the row
        broadcast_replace_to(
          [project, :inbox],
          target: "article_#{id}_row",
          partial: "projects/article_row",
          locals: { article: self, selected: false }
        )

        # Update progress counter
        broadcast_replace_to(
          [project, :inbox],
          target: "inbox-progress",
          partial: "projects/inbox_progress",
          locals: { project: project }
        )
      end
    else
      # Article leaving inbox or other status change - update progress
      broadcast_replace_to(
        [project, :inbox],
        target: "inbox-progress",
        partial: "projects/inbox_progress",
        locals: { project: project }
      )
    end

    # Notify any user viewing this article that it has been updated
    if generation_completed? && saved_change_to_generation_status?
      broadcast_append_to(
        [project, :inbox],
        target: "inbox-notifications",
        html: "<div data-article-updated-id=\"#{id}\" data-status=\"#{generation_status}\" class=\"hidden\"></div>"
      )
    end

    # Keep articles tab refresh for now (less critical)
    Turbo::StreamsChannel.broadcast_refresh_to([project, :articles])
  end
end

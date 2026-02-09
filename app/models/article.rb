class Article < ApplicationRecord
  include Turbo::Broadcastable
  include InvalidatesHelpCentreCache

  belongs_to :project
  belongs_to :recommendation
  belongs_to :section, optional: true
  has_many :step_images, dependent: :destroy
  has_many :article_update_suggestions, dependent: :nullify

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
  validates :slug, presence: true, uniqueness: { scope: :section_id }

  before_validation :generate_slug, on: :create

  scope :published, -> { where(status: :published).order(published_at: :desc) }
  scope :drafts, -> { where(status: :draft).order(created_at: :desc) }
  scope :needs_review, -> { where(review_status: :unreviewed, generation_status: :generation_completed) }
  scope :for_help_centre, -> { approved.published }
  scope :for_editor, -> { approved }
  scope :for_folder_tree, -> { where.not(review_status: :rejected) }
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

  def reindex_step_images_after_reorder(old_index, new_index)
    return if old_index == new_index

    # Use a temporary index to avoid conflicts
    temp_index = -1

    # Move the dragged item's image to temp
    moved_image = step_images.find_by(step_index: old_index)
    moved_image&.update!(step_index: temp_index)

    # Shift images between old and new positions
    if old_index < new_index
      # Moving down: shift items between old+1 and new up by 1
      step_images.where(step_index: (old_index + 1)..new_index).order(:step_index).each do |si|
        si.update!(step_index: si.step_index - 1)
      end
    else
      # Moving up: shift items between new and old-1 down by 1
      step_images.where(step_index: new_index..(old_index - 1)).order(step_index: :desc).each do |si|
        si.update!(step_index: si.step_index + 1)
      end
    end

    # Move the dragged item's image to its final position
    moved_image&.update!(step_index: new_index)
  end

  def tips
    structured_content&.dig("tips") || []
  end

  def summary
    structured_content&.dig("summary")
  end

  # Move article to a different section
  def move_to_section!(new_section)
    raise ArgumentError, "Section is required" if new_section.nil?

    new_position = new_section.articles.for_editor.maximum(:position).to_i + 1
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

    articles_scope = section.articles.for_editor

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

  def generate_slug
    return if slug.present? || title.blank?

    base_slug = title.parameterize
    candidate = base_slug
    counter = 2

    # Check uniqueness within the same section (or among uncategorized if section is nil)
    scope = if section.present?
      section.articles
    else
      project.articles.where(section: nil)
    end

    while scope.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end

  def broadcast_refreshes
    # Only broadcast for relevant status changes
    return unless saved_change_to_generation_status? || saved_change_to_review_status?

    # For inbox: add or update the article row
    if unreviewed? && (generation_pending? || generation_running? || generation_completed? || generation_failed?)
      # Replace the entire articles section (handles new articles, count updates, empty state)
      inbox_articles = project.articles
        .where(review_status: :unreviewed)
        .where(generation_status: [ :generation_pending, :generation_running, :generation_completed, :generation_failed ])
        .includes(:section)
        .order(created_at: :asc)

      broadcast_replace_to(
        [ project, :inbox ],
        target: "articles-section",
        partial: "projects/inbox_articles_section",
        locals: { inbox_articles: inbox_articles }
      )
    end

    # Always update progress counter
    broadcast_replace_to(
      [ project, :inbox ],
      target: "inbox-progress",
      partial: "projects/inbox_progress",
      locals: { project: project }
    )

    # Update tab badge
    broadcast_replace_to(
      [ project, :inbox ],
      target: "inbox-tab-badge",
      partial: "projects/inbox_tab_badge",
      locals: { project: project }
    )

    # Notify any user viewing this article that it has been updated
    if generation_completed? && saved_change_to_generation_status?
      broadcast_append_to(
        [ project, :inbox ],
        target: "inbox-notifications",
        html: "<div data-article-updated-id=\"#{id}\" data-status=\"#{generation_status}\" class=\"hidden\"></div>"
      )
    end

    # Update folder tree when generation status changes (removes "..." indicator)
    if saved_change_to_generation_status?
      broadcast_replace_to(
        [ project, :inbox ],
        target: "articles-folder-tree",
        partial: "projects/articles_folder_tree",
        locals: {
          sections: project.sections.visible.ordered,
          uncategorized_articles: project.articles.for_folder_tree.where(section: nil).ordered,
          project: project,
          selected_article_id: nil
        }
      )

      # Update articles tab badge
      broadcast_replace_to(
        [ project, :inbox ],
        target: "articles-tab-badge",
        partial: "projects/articles_tab_badge",
        locals: { project: project }
      )
    end
  end

  # Help Centre cache invalidation
  def project_for_cache
    project
  end

  def should_invalidate_help_centre_cache?
    # Invalidate when a published article is destroyed
    return true if destroyed? && status == "published"

    # Invalidate when publish status changes (published <-> draft)
    if saved_change_to_status?
      was_published = status_before_last_save == "published"
      return true if published? || was_published
    end

    # Invalidate when a published article's content changes
    return true if published? && content_fields_changed?

    false
  end

  def content_fields_changed?
    saved_change_to_structured_content? ||
      saved_change_to_content? ||
      saved_change_to_title? ||
      saved_change_to_section_id?
  end
end

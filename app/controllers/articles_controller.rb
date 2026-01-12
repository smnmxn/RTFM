class ArticlesController < ApplicationController
  before_action :require_authentication
  before_action :set_article

  def show
  end

  def regenerate
    unless @article.generation_failed? || @article.generation_completed?
      redirect_to project_path(@article.project), alert: "Article cannot be regenerated while generation is in progress"
      return
    end

    @article.update!(
      generation_status: :generation_running,
      content: "Regenerating article...",
      structured_content: nil
    )
    GenerateArticleJob.perform_later(article_id: @article.id)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(@article, partial: "articles/card", locals: { article: @article })
      }
      format.html { redirect_to project_path(@article.project), notice: "Article regeneration started" }
    end
  end

  def update_field
    field_path = params[:field]
    new_value = params[:value]

    updated_content = update_nested_field(
      (@article.structured_content || {}).deep_dup,
      field_path,
      new_value
    )

    if @article.update(structured_content: updated_content)
      @field_section = field_path.split(".").first
      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(@article, partial: "articles/card", locals: { article: @article }) }
        format.json { render json: { success: false, errors: @article.errors }, status: :unprocessable_entity }
      end
    end
  end

  def add_array_item
    field = params[:field]

    updated_content = (@article.structured_content || {}).deep_dup
    updated_content[field] ||= []

    new_item = case field
               when "steps"
                 { "title" => "New Step", "content" => "Step content here..." }
               else
                 "New item"
               end

    updated_content[field] << new_item

    if @article.update(structured_content: updated_content)
      @field = field
      respond_to do |format|
        format.turbo_stream
      end
    else
      head :unprocessable_entity
    end
  end

  def remove_array_item
    field = params[:field]
    index = params[:index].to_i

    updated_content = (@article.structured_content || {}).deep_dup
    updated_content[field]&.delete_at(index)

    if @article.update(structured_content: updated_content)
      @field = field
      respond_to do |format|
        format.turbo_stream
      end
    else
      head :unprocessable_entity
    end
  end

  def publish
    if @article.generation_completed?
      @article.publish!
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to project_article_path(@article.project, @article), notice: "Article published." }
      end
    else
      redirect_to project_article_path(@article.project, @article), alert: "Cannot publish incomplete article."
    end
  end

  def unpublish
    @article.unpublish!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_article_path(@article.project, @article), notice: "Article unpublished." }
    end
  end

  def move_to_section
    new_section_id = params[:section_id]
    new_section = new_section_id.present? ? @article.project.sections.find(new_section_id) : nil
    old_section = @article.section

    @article.move_to_section!(new_section)

    @old_section_id = old_section&.id || "uncategorized"
    @new_section_id = new_section&.id || "uncategorized"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@article.project, anchor: "articles"), notice: "Article moved." }
    end
  end

  def reorder
    direction = params[:direction]
    articles_scope = @article.section ? @article.section.articles.for_help_centre.ordered : @article.project.articles.for_help_centre.where(section: nil).ordered
    articles = articles_scope.to_a
    current_index = articles.index(@article)

    new_index = direction == "up" ? current_index - 1 : current_index + 1
    return head :unprocessable_entity if new_index < 0 || new_index >= articles.length

    # Swap positions
    other_article = articles[new_index]
    @article.position, other_article.position = other_article.position, @article.position
    @article.save!
    other_article.save!

    @articles = articles_scope.reload
    @section_id = @article.section_id || "uncategorized"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@article.project, anchor: "articles") }
    end
  end

  def duplicate
    @new_article = @article.duplicate!
    @section_id = @new_article.section_id || "uncategorized"

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_path(@article.project, anchor: "articles"), notice: "Article duplicated." }
    end
  end

  def destroy
    section_id = @article.section_id || "uncategorized"
    project = @article.project
    @article.destroy!

    respond_to do |format|
      format.turbo_stream { redirect_to project_path(project, anchor: "articles"), notice: "Article deleted." }
      format.html { redirect_to project_path(project, anchor: "articles"), notice: "Article deleted." }
    end
  end

  private

  def set_article
    @article = current_user.projects
      .joins(:articles)
      .where(articles: { id: params[:id] })
      .first!
      .articles.find(params[:id])
  end

  def update_nested_field(content, path, value)
    keys = path.split(".")
    target = content

    keys[0..-2].each do |key|
      key = key.to_i if key.match?(/^\d+$/)
      target = target[key]
    end

    final_key = keys.last
    final_key = final_key.to_i if final_key.match?(/^\d+$/)
    target[final_key] = value

    content
  end
end

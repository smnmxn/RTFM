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

class RecommendationsController < ApplicationController
  before_action :require_authentication
  before_action :set_recommendation

  def reject
    @recommendation.reject!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@recommendation) }
      format.html { redirect_back fallback_location: project_path(@recommendation.project) }
    end
  end

  def generate
    # Create article record in "running" state
    @article = Article.create!(
      project: @recommendation.project,
      recommendation: @recommendation,
      section: @recommendation.section,
      title: @recommendation.title,
      content: "Generating article...",
      generation_status: :generation_running
    )

    # Mark recommendation as generated (removes from pending list)
    @recommendation.generate!

    # Enqueue background job
    GenerateArticleJob.perform_later(article_id: @article.id)

    respond_to do |format|
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.remove(@recommendation),
          turbo_stream.prepend("articles-list", partial: "articles/card", locals: { article: @article })
        ]
      }
      format.html { redirect_to project_path(@recommendation.project) }
    end
  end

  private

  def set_recommendation
    @recommendation = current_user.projects
      .joins(:recommendations)
      .where(recommendations: { id: params[:id] })
      .first!
      .recommendations.find(params[:id])
  end
end

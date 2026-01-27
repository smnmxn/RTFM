class ArticleUpdateSuggestionsController < ApplicationController
  before_action :set_project
  before_action :set_suggestion

  def accept
    @suggestion.accept!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "suggestion_#{@suggestion.id}",
          partial: "projects/article_update_suggestion",
          locals: { suggestion: @suggestion }
        )
      end
      format.html { redirect_to project_path(@project, anchor: "settings/maintenance"), notice: "Suggestion accepted." }
    end
  end

  def dismiss
    @suggestion.dismiss!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "suggestion_#{@suggestion.id}",
          partial: "projects/article_update_suggestion",
          locals: { suggestion: @suggestion }
        )
      end
      format.html { redirect_to project_path(@project, anchor: "settings/maintenance"), notice: "Suggestion dismissed." }
    end
  end

  private

  def set_project
    @project = current_user.projects.find_by(slug: params[:project_slug])
    unless @project
      redirect_to projects_path, alert: "Project not found."
    end
  end

  def set_suggestion
    @suggestion = @project.article_update_checks
      .joins(:article_update_suggestions)
      .where(article_update_suggestions: { id: params[:id] })
      .first
      &.article_update_suggestions
      &.find(params[:id])

    unless @suggestion
      redirect_to project_path(@project), alert: "Suggestion not found."
    end
  end
end

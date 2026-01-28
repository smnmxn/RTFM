# Test-only controller for accessing the help centre without subdomain routing
# This is only loaded in the test environment
class TestHelpCentreController < ApplicationController
  skip_before_action :require_authentication

  before_action :set_project

  layout "public"

  def index
    @sections = @project.sections
      .visible
      .ordered
      .includes(articles: :recommendation)

    @popular_articles = @project.articles.published.order(published_at: :desc).limit(6)

    render "help_centre/index"
  end

  def show
    @section = @project.sections.visible.find_by!(slug: params[:section_slug])
    @article = @section.articles.published.find_by!(slug: params[:article_slug])
    @related_articles = @section.articles.published.reorder(:position).where.not(id: @article.id).limit(3)

    render "help_centre/show"
  end

  def section
    @section = @project.sections.visible.find_by!(slug: params[:section_slug])
    @articles = @section.articles.published.reorder(:position)

    render "help_centre/section"
  end

  private

  def set_project
    @project = Project.find_by!(slug: params[:project_slug])
  end
end

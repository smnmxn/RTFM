class HelpCentreController < ApplicationController
  skip_before_action :require_authentication

  before_action :set_project

  layout "public"

  def index
    @sections = @project.sections
      .visible
      .ordered
      .includes(articles: :recommendation)

    # Articles without a section
    @uncategorized_articles = @project.articles.published.where(section: nil)

    # Popular/recent articles for the homepage
    @popular_articles = @project.articles.published.order(published_at: :desc).limit(6)
  end

  def search
    @query = params[:q].to_s.strip

    if @query.present?
      @articles = @project.articles
        .published
        .where("title LIKE :q OR content LIKE :q OR structured_content LIKE :q", q: "%#{@query}%")
        .limit(20)
    else
      @articles = []
    end
  end

  def show
    @article = @project.articles.published.find(params[:id])
    @section = @article.section

    # Related articles from the same section
    @related_articles = if @section
      @section.articles.published.where.not(id: @article.id).limit(3)
    else
      []
    end
  end

  def section
    @section = @project.sections.visible.find_by!(slug: params[:section_slug])
    @articles = @section.articles.published
  end

  private

  def set_project
    @project = Project.find_by!(slug: params[:project_slug])
  end
end

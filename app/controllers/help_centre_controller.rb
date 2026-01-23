class HelpCentreController < ApplicationController
  skip_before_action :require_authentication

  before_action :set_project

  layout "public"

  def index
    @sections = @project.sections
      .visible
      .ordered
      .includes(articles: :recommendation)

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
    @section = @project.sections.visible.find_by!(slug: params[:section_slug])
    @article = @section.articles.published.find_by!(slug: params[:article_slug])

    # Related articles from the same section
    @related_articles = @section.articles.published.reorder(:position).where.not(id: @article.id).limit(3)
  end

  def section
    @section = @project.sections.visible.find_by!(slug: params[:section_slug])
    @articles = @section.articles.published.reorder(:position)
  end

  private

  def set_project
    subdomain = SubdomainConstraint.extract_subdomain(request)
    @project = Project.find_by(subdomain: subdomain)
    redirect_to_app if @project.nil?
  end

  def redirect_to_app
    base_domain = Rails.application.config.x.base_domain
    protocol = Rails.env.production? ? "https" : "http"
    redirect_to "#{protocol}://app.#{base_domain}", allow_other_host: true
  end
end

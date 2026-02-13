class HelpCentreController < ApplicationController
  skip_before_action :require_authentication

  before_action :set_project
  before_action :check_rate_limit, only: [ :ask ]

  layout "public"

  def index
    @sections = @project.sections
      .visible
      .ordered
      .includes(articles: :recommendation)

    # Popular/recent articles for the homepage
    @popular_articles = @project.articles.published.order(published_at: :desc).limit(6)
  end

  def ask
    @question = params[:q].to_s.strip

    if @question.blank?
      redirect_to help_centre_path
      return
    end

    @stream_id = SecureRandom.hex(8)

    # Increment rate limit counters
    @rate_limiter.increment!

    # Store what we need for the background thread
    project_id = @project.id
    question = @question
    stream_id = @stream_id
    skip_cache = params[:nocache].present?

    # Start streaming after response is sent
    Thread.new do
      Rails.application.executor.wrap do
        # Give the browser time to establish the ActionCable subscription
        # before we start broadcasting. Without this, cached responses
        # fire chunks before the client is listening and they're lost.
        sleep 0.5

        Rails.logger.info "[HelpCentre] Starting stream for #{stream_id}"
        project = Project.find(project_id)
        service = HelpCentreChatService.new(project, question, skip_cache: skip_cache)

        service.stream do |event|
          Rails.logger.info "[HelpCentre] Event: #{event[:type]}"
          case event[:type]
          when :chunk
            HelpCentreController.broadcast_chunk(stream_id, event[:text])
          when :complete
            HelpCentreController.broadcast_complete(stream_id, event[:sources])
          when :error
            Rails.logger.error "[HelpCentre] Error event: #{event[:message]}"
            HelpCentreController.broadcast_error(stream_id, event[:message])
          end
        end
        Rails.logger.info "[HelpCentre] Stream complete for #{stream_id}"
      rescue => e
        Rails.logger.error "[HelpCentre] Thread error: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        HelpCentreController.broadcast_error(stream_id, "Something went wrong. Please try again.")
      end
    end

    # Render page immediately with thinking state
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

  def self.broadcast_chunk(stream_id, text)
    # Escape HTML to prevent XSS, but preserve the text for JS to process
    escaped = ERB::Util.html_escape(text)
    Turbo::StreamsChannel.broadcast_append_to(
      "help_centre_ask_#{stream_id}",
      target: "answer-text",
      html: "<span>#{escaped}</span>"
    )
  end

  def self.broadcast_complete(stream_id, sources)
    html = ApplicationController.render(
      partial: "help_centre/ask_sources",
      locals: { sources: sources }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "help_centre_ask_#{stream_id}",
      target: "answer-sources",
      html: html
    )

    # Also broadcast a "done" signal to hide the cursor
    Turbo::StreamsChannel.broadcast_append_to(
      "help_centre_ask_#{stream_id}",
      target: "answer-text",
      html: "<span data-streaming-done='true'></span>"
    )
  end

  def self.broadcast_error(stream_id, message)
    html = ApplicationController.render(
      partial: "help_centre/ask_error",
      locals: { error: message }
    )
    Turbo::StreamsChannel.broadcast_replace_to(
      "help_centre_ask_#{stream_id}",
      target: "answer-container",
      html: html
    )
  end

  private

  def check_rate_limit
    @rate_limiter = HelpCentreRateLimiter.new(@project)

    if @rate_limiter.exceeded?
      @retry_after = @rate_limiter.retry_after
      @limit_info = @rate_limiter.limit_info
      response.set_header("Retry-After", @retry_after.to_s)
      render "help_centre/rate_limited", status: :too_many_requests
    end
  end

  def set_project
    # Check custom domain first
    if CustomDomainConstraint.matches?(request)
      @project = CustomDomainConstraint.find_project(request)
    else
      # Fall back to subdomain lookup
      subdomain = SubdomainConstraint.extract_subdomain(request)
      @project = Project.find_by(subdomain: subdomain)

      # Redirect to custom domain if active
      if @project&.custom_domain_active?
        redirect_to_custom_domain
        return
      end
    end
    redirect_to_app if @project.nil?
  end

  def redirect_to_app
    base_domain = Rails.application.config.x.base_domain
    protocol = Rails.env.production? ? "https" : "http"
    redirect_to "#{protocol}://app.#{base_domain}", allow_other_host: true
  end

  def redirect_to_custom_domain
    # Preserve the path when redirecting (e.g., /section/article)
    custom_url = "https://#{@project.custom_domain}#{request.fullpath}"
    redirect_to custom_url, allow_other_host: true, status: :moved_permanently
  end
end

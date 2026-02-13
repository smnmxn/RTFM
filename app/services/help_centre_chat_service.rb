require "net/http"
require "json"
require "uri"
require "digest"

class HelpCentreChatService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
  MODEL = "claude-sonnet-4-20250514"
  MAX_TOKENS = 2048
  MAX_CONTEXT_TOKENS = 150_000
  CACHE_PREFIX = "help_centre_chat:v1"

  def initialize(project, question, skip_cache: false)
    @project = project
    @question = question.to_s.strip
    @skip_cache = skip_cache
  end

  def call
    return { error: "Please enter a question" } if @question.blank?
    return { error: "Ask a question is temporarily unavailable" } unless ENV["ANTHROPIC_API_KEY"].present?

    articles = fetch_published_articles
    return { error: "No articles available yet" } if articles.empty?

    context = build_articles_context(articles)

    if estimated_tokens(context) > MAX_CONTEXT_TOKENS
      # Truncate to most recent 100 articles
      articles = articles.limit(100)
      context = build_articles_context(articles)
    end

    response = call_claude_api(context)
    parse_response(response, articles)
  rescue StandardError => e
    Rails.logger.error "[HelpCentreChatService] Error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    { error: "Unable to process your question. Please try again." }
  end

  # Streaming version - yields events as they arrive
  def stream(&block)
    if @question.blank?
      yield({ type: :error, message: "Please enter a question" })
      return
    end

    unless ENV["ANTHROPIC_API_KEY"].present?
      yield({ type: :error, message: "Ask a question is temporarily unavailable" })
      return
    end

    # Check cache first
    unless @skip_cache
      if (cached = read_cache)
        Rails.logger.info "[HelpCentreCache] HIT project=#{@project.id} question_hash=#{question_hash}"
        stream_cached_response(cached, &block)
        return
      end
    end

    Rails.logger.info "[HelpCentreCache] MISS project=#{@project.id} question_hash=#{question_hash}"

    Rails.logger.info "[HelpCentreChatService] Fetching articles..."
    articles = fetch_published_articles
    if articles.empty?
      yield({ type: :error, message: "No articles available yet" })
      return
    end
    Rails.logger.info "[HelpCentreChatService] Found #{articles.count} articles"

    Rails.logger.info "[HelpCentreChatService] Building context..."
    context = build_articles_context(articles)
    Rails.logger.info "[HelpCentreChatService] Context built (#{context.length} chars)"

    if estimated_tokens(context) > MAX_CONTEXT_TOKENS
      articles = articles.limit(100)
      context = build_articles_context(articles)
    end

    full_text = ""

    Rails.logger.info "[HelpCentreChatService] Calling Claude API..."
    stream_claude_api(context) do |chunk|
      full_text += chunk
      yield({ type: :chunk, text: chunk })
    end

    # After streaming complete, extract and yield sources
    sources = extract_sources(full_text, articles)

    # Cache the successful response
    write_cache(full_text, sources)

    yield({ type: :complete, sources: sources, full_text: full_text })
  rescue StandardError => e
    Rails.logger.error "[HelpCentreChatService] Stream error: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    yield({ type: :error, message: "Unable to process your question. Please try again." })
  end

  private

  def fetch_published_articles
    @project.articles
      .published
      .includes(:section, step_images: { image_attachment: :blob })
      .order(published_at: :desc)
  end

  def build_articles_context(articles)
    articles.map do |article|
      section_name = article.section&.name || "General"
      section_slug = article.section&.slug || "general"
      url = "/#{section_slug}/#{article.slug}"

      content_text = extract_article_content(article)

      <<~ARTICLE
        ---
        TITLE: #{article.title}
        SECTION: #{section_name}
        URL: #{url}
        CONTENT:
        #{content_text}
        ---
      ARTICLE
    end.join("\n")
  end

  def extract_article_content(article)
    if article.structured?
      parts = []
      parts << article.introduction if article.introduction.present?

      if article.prerequisites.any?
        parts << "Prerequisites: #{article.prerequisites.join(', ')}"
      end

      if article.steps.any?
        steps_text = article.steps.map.with_index do |step, i|
          step_image = article.step_images.find { |si| si.step_index == i }
          image_info = ""
          if step_image&.image&.attached?
            url = step_image_url(step_image)
            image_info = "\n  [Image available: #{url}]" if url
          end
          "Step #{i + 1}: #{step['title']} - #{step['content']}#{image_info}"
        end.join("\n")
        parts << steps_text
      end

      if article.tips.any?
        parts << "Tips: #{article.tips.join(', ')}"
      end

      parts << article.summary if article.summary.present?
      parts.join("\n\n")
    else
      article.content.to_s
    end
  end

  def build_system_prompt(articles_context)
    support_contact = build_support_contact_info

    <<~PROMPT
      You ARE the #{@project.name} help centre. The knowledge below is yours — answer as if you just know these things, the way a knowledgeable team member would.

      VOICE — CRITICAL:
      - NEVER reference articles, documentation, guides, help pages, or "the information I have". You don't "have access to" anything — you simply know things or you don't.
      - NEVER say: "I checked…", "based on the documentation…", "in our help articles…", "the articles I can help with cover…", "I don't have information about X in…", or ANY variation that reveals you are searching or reading a knowledge base.
      - Instead of "I don't have information about X", just say "That's not something I can help with right now" or similar.
      - Instead of "The articles I can help with cover X, Y, Z", just say "I can help with X, Y, Z" — own it.

      ANSWERING:
      1. Answer directly and concisely.
      2. When linking to a relevant page, cite it as a markdown link: [Title](URL).
      3. Never make up information you don't have.
      4. Use a friendly, helpful tone. Format with markdown for readability.
      5. IMAGES — actively include images from the knowledge base when they're relevant. They make answers much more useful. Use: ![description](image_url). Only use images marked [Image available: URL] in the knowledge below. Place them inline after the text they illustrate. If a step-by-step answer has images available for those steps, include them.
      6. This is a single question-and-answer, NOT a chat. There is no way for the user to reply. NEVER end with anything that implies a continuing conversation like "Is there anything else I can help with?", "Let me know if you need more details", "Feel free to ask if you have questions", "Hope that helps!", "Would you like me to explain further?", etc. Just answer and stop.

      WHEN YOU DON'T KNOW:
      - Say so naturally and briefly — no scripted fallback phrases.
      - Suggest related things you CAN help with, or recommend browsing a category.
      #{support_contact}

      ---
      #{articles_context}
    PROMPT
  end

  def build_support_contact_info
    parts = []
    parts << @project.support_email if @project.support_email.present?
    parts << @project.support_phone if @project.support_phone.present?

    if parts.any?
      "- Offer to connect them with the support team: #{parts.join(' or ')}"
    else
      ""
    end
  end

  def call_claude_api(articles_context)
    uri = URI(ANTHROPIC_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"

    request.body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: build_system_prompt(articles_context),
      messages: [
        { role: "user", content: @question }
      ]
    }.to_json

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error "[HelpCentreChatService] API error: #{response.code} - #{response.body}"
      nil
    end
  end

  def stream_claude_api(articles_context, &block)
    uri = URI(ANTHROPIC_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"

    request.body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      stream: true,
      system: build_system_prompt(articles_context),
      messages: [
        { role: "user", content: @question }
      ]
    }.to_json

    http.request(request) do |response|
      if response.code != "200"
        Rails.logger.error "[HelpCentreChatService] Stream API error: #{response.code}"
        raise "API error: #{response.code}"
      end

      buffer = ""
      response.read_body do |chunk|
        buffer += chunk

        # Parse SSE events from buffer
        while (event_end = buffer.index("\n\n"))
          event_data = buffer[0...event_end]
          buffer = buffer[(event_end + 2)..]

          # Parse the event
          parse_sse_event(event_data, &block)
        end
      end
    end
  end

  def parse_sse_event(event_data, &block)
    lines = event_data.split("\n")
    event_type = nil
    data = nil

    lines.each do |line|
      if line.start_with?("event: ")
        event_type = line[7..]
      elsif line.start_with?("data: ")
        data = line[6..]
      end
    end

    return unless data

    begin
      parsed = JSON.parse(data)

      case parsed["type"]
      when "content_block_delta"
        if parsed.dig("delta", "type") == "text_delta"
          text = parsed.dig("delta", "text")
          yield(text) if text
        end
      when "message_stop"
        # Stream complete
      when "error"
        Rails.logger.error "[HelpCentreChatService] Stream error: #{parsed}"
      end
    rescue JSON::ParserError
      # Ignore non-JSON data lines
    end
  end

  def extract_sources(full_text, articles)
    cited_urls = full_text.scan(/\[([^\]]+)\]\(([^)]+)\)/).map { |_, url| url }

    articles.select do |article|
      section_slug = article.section&.slug || "general"
      url = "/#{section_slug}/#{article.slug}"
      cited_urls.include?(url)
    end.map do |article|
      section_slug = article.section&.slug || "general"
      {
        id: article.id,
        title: article.title,
        section: article.section&.name,
        url: "/#{section_slug}/#{article.slug}"
      }
    end.uniq { |s| s[:id] }
  end

  def parse_response(response, articles)
    return { error: "Unable to get a response. Please try again." } unless response

    content = response.dig("content", 0, "text")
    return { error: "Empty response received. Please try again." } unless content

    # Extract cited URLs from markdown links in the response
    cited_urls = content.scan(/\[([^\]]+)\]\(([^)]+)\)/).map { |_, url| url }

    # Build sources array from cited articles
    sources = articles.select do |article|
      section_slug = article.section&.slug || "general"
      url = "/#{section_slug}/#{article.slug}"
      cited_urls.include?(url)
    end.map do |article|
      section_slug = article.section&.slug || "general"
      {
        id: article.id,
        title: article.title,
        section: article.section&.name,
        url: "/#{section_slug}/#{article.slug}"
      }
    end

    {
      answer: content,
      sources: sources.uniq { |s| s[:id] }
    }
  end

  def estimated_tokens(text)
    # Rough estimate: ~4 characters per token
    (text.length / 4.0).ceil
  end

  def step_image_url(step_image)
    return nil unless step_image&.image&.attached?

    host = build_image_host
    # Use original blob URL to avoid blocking on variant processing
    Rails.application.routes.url_helpers.rails_blob_url(
      step_image.image,
      host: host
    )
  rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError => e
    Rails.logger.warn "[HelpCentreChatService] Image not available for step_image #{step_image.id}: #{e.message}"
    nil
  rescue => e
    Rails.logger.error "[HelpCentreChatService] Unexpected error getting image URL: #{e.class} - #{e.message}"
    nil
  end

  def build_image_host
    base_domain = Rails.application.config.x.base_domain
    protocol = Rails.env.production? ? "https" : "http"
    "#{protocol}://#{@project.subdomain}.#{base_domain}"
  end

  # Caching methods

  def cache_key
    "#{CACHE_PREFIX}:project_#{@project.id}:content_#{@project.help_centre_cache_version}:q_#{question_hash}"
  end

  def question_hash
    @question_hash ||= Digest::SHA256.hexdigest(normalize_question(@question))[0..15]
  end

  def normalize_question(question)
    question.to_s.strip.downcase.gsub(/[^\w\s]/, "").gsub(/\s+/, " ")
  end

  def read_cache
    Rails.cache.read(cache_key)
  end

  def write_cache(full_text, sources)
    Rails.cache.write(
      cache_key,
      { full_text: full_text, sources: sources }
    )
    Rails.logger.info "[HelpCentreCache] WRITE project=#{@project.id} version=#{@project.help_centre_cache_version}"
  end

  # Simulated streaming for cached responses

  def stream_cached_response(cached_data, &block)
    chunks = split_into_natural_chunks(cached_data[:full_text])

    chunks.each do |chunk|
      yield({ type: :chunk, text: chunk })
      sleep(calculate_chunk_delay(chunk))
    end

    yield({ type: :complete, sources: cached_data[:sources], full_text: cached_data[:full_text] })
  end

  def split_into_natural_chunks(text)
    chunks = []
    buffer = ""

    text.each_char do |char|
      buffer += char

      # Yield chunk at natural breakpoints (punctuation or max length)
      if buffer.length >= 15 && (char.match?(/[.!?,:\n]/) || buffer.length >= 40)
        chunks << buffer
        buffer = ""
      end
    end

    chunks << buffer unless buffer.empty?
    chunks
  end

  def calculate_chunk_delay(chunk)
    # Base delay ~30ms per chunk with slight variance
    base_delay = 0.03
    variance = rand(-0.01..0.02)
    length_factor = [ chunk.length / 100.0, 0.02 ].min
    [ base_delay + variance + length_factor, 0.01 ].max
  end
end

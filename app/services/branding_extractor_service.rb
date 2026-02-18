require "net/http"
require "json"
require "uri"

class BrandingExtractorService
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
  MODEL = "claude-haiku-4-5-20251001"
  MAX_TOKENS = 1024
  MAX_HTML_SIZE = 500_000 # 500KB
  HTTP_TIMEOUT = 10
  MAX_REDIRECTS = 3

  Result = Struct.new(:success?, :primary_color, :accent_color, :logo_url, :favicon_url, :dark_mode, :error, keyword_init: true)

  def initialize(url)
    @url = url
  end

  def extract
    return Result.new("success?": false, error: "No API key") unless ENV["ANTHROPIC_API_KEY"].present?

    html = fetch_html(@url)
    return Result.new("success?": false, error: "Could not fetch website") unless html

    response = call_claude_api(build_prompt(html))
    parse_response(response)
  rescue StandardError => e
    Rails.logger.error "[BrandingExtractorService] Error: #{e.message}"
    Result.new("success?": false, error: e.message)
  end

  private

  def fetch_html(url, redirects = 0)
    return nil if redirects > MAX_REDIRECTS

    uri = URI(url)
    uri = URI("https://#{url}") unless uri.scheme
    return nil unless uri.is_a?(URI::HTTP)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = HTTP_TIMEOUT
    http.read_timeout = HTTP_TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (compatible; RTFMBot/1.0)"
    request["Accept"] = "text/html"

    response = http.request(request)

    case response
    when Net::HTTPRedirection
      fetch_html(response["location"], redirects + 1)
    when Net::HTTPSuccess
      body = response.body.to_s
      body.length > MAX_HTML_SIZE ? body[0...MAX_HTML_SIZE] : body
    end
  rescue StandardError => e
    Rails.logger.warn "[BrandingExtractorService] HTTP error fetching #{url}: #{e.message}"
    nil
  end

  def build_prompt(html)
    # Trim HTML to reduce token usage — keep head and first portion of body
    trimmed = trim_html(html)

    <<~PROMPT
      Analyze this website's HTML and extract the brand identity. Return ONLY valid JSON (no markdown, no explanation) in this exact format:

      {
        "primary_color": "#hex",
        "accent_color": "#hex",
        "logo_url": "absolute URL or null",
        "favicon_url": "absolute URL or null",
        "dark_mode": false
      }

      Rules:
      - primary_color: The main brand color used in the header/nav/buttons. Must be a 6-digit hex code.
      - accent_color: A secondary/complementary brand color. Must be a 6-digit hex code.
      - logo_url: The URL of the main logo image from the header/nav. Look for <img> tags inside <header>, <nav>, or elements with class names containing "logo", "brand", or "header". Return the full absolute URL. Return null if not found.
      - favicon_url: The URL from <link rel="icon"> or <link rel="shortcut icon">. Return the full absolute URL. Return null if not found.
      - dark_mode: true if the site primarily uses a dark background theme, false otherwise.
      - Do NOT return generic colors like pure black (#000000) or pure white (#ffffff) as the primary color unless the brand truly uses them.
      - If you cannot determine a color, use a reasonable default based on any brand colors you can find.

      Website URL: #{@url}

      HTML:
      #{trimmed}
    PROMPT
  end

  def trim_html(html)
    # Keep the full <head> and a reasonable chunk of the <body>
    head_match = html.match(/<head[^>]*>(.*?)<\/head>/mi)
    body_match = html.match(/<body[^>]*>(.*)/mi)

    parts = []
    parts << "<head>#{head_match[1]}</head>" if head_match
    if body_match
      body_content = body_match[1][0..50_000] # First 50KB of body
      parts << "<body>#{body_content}</body>"
    end

    parts.any? ? parts.join("\n") : html[0..50_000]
  end

  def call_claude_api(prompt)
    uri = URI(ANTHROPIC_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"

    request.body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [
        { role: "user", content: prompt }
      ]
    }.to_json

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error "[BrandingExtractorService] API error: #{response.code} - #{response.body}"
      nil
    end
  end

  def parse_response(response)
    return Result.new("success?": false, error: "No API response") unless response

    content = response.dig("content", 0, "text")
    return Result.new("success?": false, error: "No content in response") unless content

    clean_json = content
      .gsub(/\A\s*```json\s*/i, "")
      .gsub(/\s*```\s*\z/, "")
      .strip

    parsed = JSON.parse(clean_json)

    # Resolve relative URLs to absolute
    base_uri = URI(@url) rescue nil
    logo_url = resolve_url(parsed["logo_url"], base_uri)
    favicon_url = resolve_url(parsed["favicon_url"], base_uri)

    Result.new(
      "success?": true,
      primary_color: normalize_hex(parsed["primary_color"]),
      accent_color: normalize_hex(parsed["accent_color"]),
      logo_url: logo_url,
      favicon_url: favicon_url,
      dark_mode: parsed["dark_mode"] == true
    )
  rescue JSON::ParserError => e
    Rails.logger.error "[BrandingExtractorService] JSON parse error: #{e.message}"
    Result.new("success?": false, error: "Invalid JSON response")
  end

  def resolve_url(url, base_uri)
    return nil if url.blank? || url == "null"
    return url if url.start_with?("http://", "https://")
    return nil unless base_uri

    URI.join("#{base_uri.scheme}://#{base_uri.host}", url).to_s
  rescue URI::InvalidURIError
    nil
  end

  def normalize_hex(color)
    return nil if color.blank?
    color = "##{color}" unless color.start_with?("#")
    return color if color.match?(/\A#[0-9a-fA-F]{6}\z/)
    nil
  end
end

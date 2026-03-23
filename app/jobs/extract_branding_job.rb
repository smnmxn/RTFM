class ExtractBrandingJob < ApplicationJob
  queue_as :default

  def perform(project_id, website_url, force: false)
    @force = force
    project = Project.find_by(id: project_id)
    return unless project

    result = BrandingExtractorService.new(website_url).extract

    unless result.success?
      Rails.logger.warn "[ExtractBrandingJob] Extraction failed for project #{project_id}: #{result.error}"
      return
    end

    apply_branding(project, result)
    attach_logo(project, result)
    attach_favicon(project, result)
  rescue StandardError => e
    Rollbar.error(e, project_id: project_id)
    Rails.logger.error "[ExtractBrandingJob] Error for project #{project_id}: #{e.message}"
  end

  private

  # Default branding colors that should be treated as "not yet configured"
  DEFAULT_COLORS = %w[#4f46e5 #7c3aed].freeze

  def apply_branding(project, result)
    branding = project.branding || {}

    if @force
      branding["primary_color"] = result.primary_color if result.primary_color.present?
      branding["accent_color"] = result.accent_color if result.accent_color.present?
      branding["gradient_start_color"] = result.primary_color if result.primary_color.present?
      branding["dark_mode"] = result.dark_mode
    else
      branding["primary_color"] = result.primary_color if color_is_default?(branding["primary_color"]) && result.primary_color.present?
      branding["accent_color"] = result.accent_color if color_is_default?(branding["accent_color"]) && result.accent_color.present?
      branding["gradient_start_color"] = result.primary_color if branding["gradient_start_color"].blank? && result.primary_color.present?
      branding["dark_mode"] = result.dark_mode if branding["dark_mode"].nil?
    end

    project.update!(branding: branding)
  end

  def color_is_default?(color)
    color.blank? || DEFAULT_COLORS.include?(color)
  end

  def attach_logo(project, result)
    return if project.logo.attached? && !@force

    # Try logo first, fall back to favicon
    image_url = result.logo_url.presence || result.favicon_url.presence
    return unless image_url

    image_data = download_image(image_url)
    return unless image_data

    filename = File.basename(URI.parse(image_url).path).presence || "logo"
    filename = "#{filename}.png" unless filename.include?(".")
    content_type = detect_content_type(image_data, filename)

    io = StringIO.new(image_data)
    io.binmode

    project.logo.attach(
      io: io,
      filename: filename,
      content_type: content_type
    )

    Rails.logger.info "[ExtractBrandingJob] Attached logo for project #{project.id} from #{image_url}"
  rescue StandardError => e
    Rails.logger.warn "[ExtractBrandingJob] Failed to attach logo for project #{project.id}: #{e.message}"
  end

  def attach_favicon(project, result)
    return if project.favicon.attached? && !@force
    return if result.favicon_url.blank?

    image_data = download_image(result.favicon_url)
    return unless image_data

    filename = File.basename(URI.parse(result.favicon_url).path).presence || "favicon"
    filename = "#{filename}.png" unless filename.include?(".")
    content_type = detect_content_type(image_data, filename)

    io = StringIO.new(image_data)
    io.binmode

    project.favicon.attach(
      io: io,
      filename: filename,
      content_type: content_type
    )

    Rails.logger.info "[ExtractBrandingJob] Attached favicon for project #{project.id} from #{result.favicon_url}"
  rescue StandardError => e
    Rails.logger.warn "[ExtractBrandingJob] Failed to attach favicon for project #{project.id}: #{e.message}"
  end

  def download_image(url, redirects = 0)
    return nil if redirects > 3

    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Mozilla/5.0 (compatible; RTFMBot/1.0)"

    response = http.request(request)

    case response
    when Net::HTTPRedirection
      download_image(response["location"], redirects + 1)
    when Net::HTTPSuccess
      body = response.body
      # Sanity check: reject if too large (> 5MB) or empty
      return nil if body.nil? || body.empty? || body.length > 5_000_000
      body
    end
  rescue StandardError => e
    Rails.logger.warn "[ExtractBrandingJob] Failed to download image #{url}: #{e.message}"
    nil
  end

  def detect_content_type(data, filename)
    # Check magic bytes
    if data[0..7].bytes == [137, 80, 78, 71, 13, 10, 26, 10]
      "image/png"
    elsif data[0..2].bytes == [255, 216, 255]
      "image/jpeg"
    elsif data[0..3] == "RIFF" && data[8..11] == "WEBP"
      "image/webp"
    elsif data.include?("<svg")
      "image/svg+xml"
    elsif data[0..2].bytes == [71, 73, 70]
      "image/gif"
    elsif data[0..3].bytes == [0, 0, 1, 0]
      "image/x-icon"
    else
      # Fall back to extension
      case File.extname(filename).downcase
      when ".png" then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".svg" then "image/svg+xml"
      when ".webp" then "image/webp"
      when ".gif" then "image/gif"
      when ".ico" then "image/x-icon"
      else "image/png"
      end
    end
  end
end

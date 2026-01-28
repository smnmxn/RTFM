require "net/http"
require "json"

class CloudflareCustomHostnameService
  BASE_URL = "https://api.cloudflare.com/client/v4"

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error
    attr_reader :status, :errors

    def initialize(message, status: nil, errors: nil)
      super(message)
      @status = status
      @errors = errors
    end
  end

  def initialize
    @zone_id = ENV["CLOUDFLARE_ZONE_ID"]
    @api_token = ENV["CLOUDFLARE_API_TOKEN"]
    @fallback_origin = ENV.fetch("CLOUDFLARE_FALLBACK_ORIGIN", "supportpages.io")

    validate_configuration!
  end

  def create_custom_hostname(hostname)
    response = post("/zones/#{@zone_id}/custom_hostnames", {
      hostname: hostname,
      ssl: {
        method: "http",
        type: "dv",
        settings: {
          min_tls_version: "1.2"
        }
      }
    })

    {
      id: response.dig("result", "id"),
      hostname: response.dig("result", "hostname"),
      status: response.dig("result", "status"),
      ssl_status: response.dig("result", "ssl", "status"),
      verification_errors: response.dig("result", "verification_errors"),
      ownership_verification: response.dig("result", "ownership_verification"),
      ownership_verification_http: response.dig("result", "ownership_verification_http")
    }
  end

  def get_custom_hostname(id)
    response = get("/zones/#{@zone_id}/custom_hostnames/#{id}")

    {
      id: response.dig("result", "id"),
      hostname: response.dig("result", "hostname"),
      status: response.dig("result", "status"),
      ssl_status: response.dig("result", "ssl", "status"),
      ssl_validation_errors: response.dig("result", "ssl", "validation_errors"),
      verification_errors: response.dig("result", "verification_errors"),
      ownership_verification: response.dig("result", "ownership_verification"),
      ownership_verification_http: response.dig("result", "ownership_verification_http")
    }
  end

  def delete_custom_hostname(id)
    response = delete("/zones/#{@zone_id}/custom_hostnames/#{id}")
    response["success"]
  end

  def configured?
    @zone_id.present? && @api_token.present?
  end

  private

  def validate_configuration!
    return if configured?

    Rails.logger.warn "[CloudflareCustomHostnameService] Missing configuration - custom domains will not work"
  end

  def get(path)
    request(:get, path)
  end

  def post(path, body)
    request(:post, path, body)
  end

  def delete(path)
    request(:delete, path)
  end

  def request(method, path, body = nil)
    raise ConfigurationError, "Cloudflare API not configured" unless configured?

    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 10

    req = case method
    when :get
      Net::HTTP::Get.new(uri)
    when :post
      Net::HTTP::Post.new(uri)
    when :delete
      Net::HTTP::Delete.new(uri)
    end

    req["Authorization"] = "Bearer #{@api_token}"
    req["Content-Type"] = "application/json"
    req.body = body.to_json if body

    response = http.request(req)
    parsed = JSON.parse(response.body)

    unless parsed["success"]
      errors = parsed["errors"]&.map { |e| e["message"] }&.join(", ") || "Unknown error"
      raise ApiError.new(
        "Cloudflare API error: #{errors}",
        status: response.code.to_i,
        errors: parsed["errors"]
      )
    end

    parsed
  rescue JSON::ParserError
    raise ApiError.new("Invalid JSON response from Cloudflare", status: response&.code&.to_i)
  rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
    raise ApiError.new("Cloudflare API timeout")
  end
end

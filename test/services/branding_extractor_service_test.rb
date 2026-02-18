require "test_helper"

class BrandingExtractorServiceTest < ActiveSupport::TestCase
  setup do
    @original_api_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
  end

  teardown do
    ENV["ANTHROPIC_API_KEY"] = @original_api_key
  end

  test "returns failure when API key is missing" do
    ENV["ANTHROPIC_API_KEY"] = nil
    service = BrandingExtractorService.new("https://example.com")
    result = service.extract
    assert_not result.success?
    assert_equal "No API key", result.error
  end

  test "extracts branding from successful response" do
    api_response = {
      "content" => [ {
        "text" => {
          "primary_color" => "#4f46e5",
          "accent_color" => "#7c3aed",
          "logo_url" => "https://example.com/logo.png",
          "favicon_url" => "https://example.com/favicon.ico",
          "dark_mode" => false
        }.to_json
      } ]
    }

    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html><body>Test</body></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| api_response }

    result = service.extract

    assert result.success?
    assert_equal "#4f46e5", result.primary_color
    assert_equal "#7c3aed", result.accent_color
    assert_equal "https://example.com/logo.png", result.logo_url
    assert_equal "https://example.com/favicon.ico", result.favicon_url
    assert_equal false, result.dark_mode
  end

  test "handles failed HTML fetch" do
    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| nil }

    result = service.extract
    assert_not result.success?
    assert_equal "Could not fetch website", result.error
  end

  test "handles failed API response" do
    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html><body>Hello</body></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| nil }

    result = service.extract
    assert_not result.success?
  end

  test "resolves relative URLs to absolute" do
    api_response = {
      "content" => [ {
        "text" => {
          "primary_color" => "#ff0000",
          "accent_color" => "#00ff00",
          "logo_url" => "/images/logo.png",
          "favicon_url" => "/favicon.ico",
          "dark_mode" => false
        }.to_json
      } ]
    }

    service = BrandingExtractorService.new("https://example.com/page")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| api_response }

    result = service.extract

    assert result.success?
    assert_equal "https://example.com/images/logo.png", result.logo_url
    assert_equal "https://example.com/favicon.ico", result.favicon_url
  end

  test "normalizes hex colors" do
    api_response = {
      "content" => [ {
        "text" => {
          "primary_color" => "4f46e5",
          "accent_color" => "#7C3AED",
          "logo_url" => nil,
          "favicon_url" => nil,
          "dark_mode" => false
        }.to_json
      } ]
    }

    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| api_response }

    result = service.extract

    assert result.success?
    assert_equal "#4f46e5", result.primary_color
    assert_equal "#7C3AED", result.accent_color
  end

  test "handles invalid JSON in response" do
    api_response = {
      "content" => [ { "text" => "not valid json" } ]
    }

    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| api_response }

    result = service.extract
    assert_not result.success?
    assert_equal "Invalid JSON response", result.error
  end

  test "handles dark mode detection" do
    api_response = {
      "content" => [ {
        "text" => {
          "primary_color" => "#ffffff",
          "accent_color" => "#cccccc",
          "logo_url" => nil,
          "favicon_url" => nil,
          "dark_mode" => true
        }.to_json
      } ]
    }

    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| api_response }

    result = service.extract

    assert result.success?
    assert_equal true, result.dark_mode
  end

  test "handles null logo and favicon URLs" do
    api_response = {
      "content" => [ {
        "text" => {
          "primary_color" => "#ff0000",
          "accent_color" => "#00ff00",
          "logo_url" => "null",
          "favicon_url" => nil,
          "dark_mode" => false
        }.to_json
      } ]
    }

    service = BrandingExtractorService.new("https://example.com")
    service.define_singleton_method(:fetch_html) { |_url, _r = 0| "<html></html>" }
    service.define_singleton_method(:call_claude_api) { |_prompt| api_response }

    result = service.extract

    assert result.success?
    assert_nil result.logo_url
    assert_nil result.favicon_url
  end
end

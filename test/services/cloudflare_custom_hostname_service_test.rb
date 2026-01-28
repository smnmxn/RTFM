require "test_helper"

class CloudflareCustomHostnameServiceTest < ActiveSupport::TestCase
  setup do
    @original_zone_id = ENV["CLOUDFLARE_ZONE_ID"]
    @original_api_token = ENV["CLOUDFLARE_API_TOKEN"]
  end

  teardown do
    ENV["CLOUDFLARE_ZONE_ID"] = @original_zone_id
    ENV["CLOUDFLARE_API_TOKEN"] = @original_api_token
  end

  test "configured? returns false when zone_id is missing" do
    ENV["CLOUDFLARE_ZONE_ID"] = nil
    ENV["CLOUDFLARE_API_TOKEN"] = "test-token"
    service = CloudflareCustomHostnameService.new
    assert_not service.configured?
  end

  test "configured? returns false when api_token is missing" do
    ENV["CLOUDFLARE_ZONE_ID"] = "test-zone"
    ENV["CLOUDFLARE_API_TOKEN"] = nil
    service = CloudflareCustomHostnameService.new
    assert_not service.configured?
  end

  test "configured? returns true when both are present" do
    ENV["CLOUDFLARE_ZONE_ID"] = "test-zone"
    ENV["CLOUDFLARE_API_TOKEN"] = "test-token"
    service = CloudflareCustomHostnameService.new
    assert service.configured?
  end

  test "create_custom_hostname raises ConfigurationError when not configured" do
    ENV["CLOUDFLARE_ZONE_ID"] = nil
    ENV["CLOUDFLARE_API_TOKEN"] = nil
    service = CloudflareCustomHostnameService.new

    assert_raises(CloudflareCustomHostnameService::ConfigurationError) do
      service.create_custom_hostname("help.example.com")
    end
  end

  test "get_custom_hostname raises ConfigurationError when not configured" do
    ENV["CLOUDFLARE_ZONE_ID"] = nil
    ENV["CLOUDFLARE_API_TOKEN"] = nil
    service = CloudflareCustomHostnameService.new

    assert_raises(CloudflareCustomHostnameService::ConfigurationError) do
      service.get_custom_hostname("test-id")
    end
  end

  test "delete_custom_hostname raises ConfigurationError when not configured" do
    ENV["CLOUDFLARE_ZONE_ID"] = nil
    ENV["CLOUDFLARE_API_TOKEN"] = nil
    service = CloudflareCustomHostnameService.new

    assert_raises(CloudflareCustomHostnameService::ConfigurationError) do
      service.delete_custom_hostname("test-id")
    end
  end
end

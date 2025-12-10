require "test_helper"
require "ostruct"

class GithubWebhookServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  class FakeOctokitClient
    attr_accessor :create_hook_response, :create_hook_error, :remove_hook_error

    def initialize(create_hook_response: nil, create_hook_error: nil, remove_hook_error: nil)
      @create_hook_response = create_hook_response
      @create_hook_error = create_hook_error
      @remove_hook_error = remove_hook_error
    end

    def create_hook(repo, type, config, options = {})
      raise @create_hook_error if @create_hook_error
      @create_hook_response || OpenStruct.new(id: 12345)
    end

    def remove_hook(repo, hook_id)
      raise @remove_hook_error if @remove_hook_error
      true
    end
  end

  def service_with_client(client)
    service = GithubWebhookService.new(@user)
    service.instance_variable_set(:@client, client)
    service
  end

  test "creates webhook successfully" do
    fake_client = FakeOctokitClient.new(create_hook_response: OpenStruct.new(id: 99999))
    service = service_with_client(fake_client)

    result = service.create(
      repo_full_name: "owner/repo",
      webhook_secret: "secret123",
      webhook_url: "https://example.com/webhooks/github"
    )

    assert result.success?
    assert_equal 99999, result.webhook_id
  end

  test "handles webhook already exists error" do
    error = Octokit::UnprocessableEntity.new(body: { message: "Hook already exists on this repository" })
    fake_client = FakeOctokitClient.new(create_hook_error: error)
    service = service_with_client(fake_client)

    result = service.create(
      repo_full_name: "owner/repo",
      webhook_secret: "secret123",
      webhook_url: "https://example.com/webhooks/github"
    )

    assert_not result.success?
    assert_equal :webhook_exists, result.error
  end

  test "handles no admin access error" do
    fake_client = FakeOctokitClient.new(create_hook_error: Octokit::Forbidden.new)
    service = service_with_client(fake_client)

    result = service.create(
      repo_full_name: "owner/repo",
      webhook_secret: "secret123",
      webhook_url: "https://example.com/webhooks/github"
    )

    assert_not result.success?
    assert_equal :no_admin_access, result.error
  end

  test "handles repo not found error" do
    fake_client = FakeOctokitClient.new(create_hook_error: Octokit::NotFound.new)
    service = service_with_client(fake_client)

    result = service.create(
      repo_full_name: "owner/repo",
      webhook_secret: "secret123",
      webhook_url: "https://example.com/webhooks/github"
    )

    assert_not result.success?
    assert_equal :repo_not_found, result.error
  end

  test "deletes webhook successfully" do
    fake_client = FakeOctokitClient.new
    service = service_with_client(fake_client)

    result = service.delete(repo_full_name: "owner/repo", webhook_id: 12345)

    assert result.success?
  end

  test "handles delete error gracefully" do
    fake_client = FakeOctokitClient.new(remove_hook_error: Octokit::NotFound.new)
    service = service_with_client(fake_client)

    result = service.delete(repo_full_name: "owner/repo", webhook_id: 12345)

    assert_not result.success?
  end
end

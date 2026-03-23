require "test_helper"

class Webhooks::BitbucketControllerTest < ActionDispatch::IntegrationTest
  setup do
    @webhook_secret = "test_bitbucket_webhook_secret"
    ENV["BITBUCKET_WEBHOOK_SECRET"] = @webhook_secret
  end

  teardown do
    ENV.delete("BITBUCKET_WEBHOOK_SECRET")
  end

  test "rejects requests with invalid signature" do
    payload = { repository: { full_name: "ws/repo" } }.to_json

    post webhooks_bitbucket_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature" => "sha256=invalid",
        "X-Event-Key" => "pullrequest:fulfilled"
      }

    assert_response :unauthorized
  end

  test "rejects requests with missing signature" do
    payload = { repository: { full_name: "ws/repo" } }.to_json

    post webhooks_bitbucket_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Event-Key" => "pullrequest:fulfilled"
      }

    assert_response :unauthorized
  end

  test "returns not_found when no project matches repo" do
    payload = {
      pullrequest: {
        id: 1,
        title: "Test PR",
        description: "",
        links: { html: { href: "https://bitbucket.org/ws/unknown-repo/pull-requests/1" } },
        merge_commit: { hash: "abc123" },
        destination: { branch: { name: "main" } }
      },
      repository: { full_name: "ws/unknown-repo" }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", @webhook_secret, payload)

    post webhooks_bitbucket_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature" => signature,
        "X-Event-Key" => "pullrequest:fulfilled"
      }

    assert_response :not_found
  end

  test "accepts and enqueues job for valid PR webhook" do
    # Create a Bitbucket project repository
    project = projects(:one)
    repo_name = "bb-workspace/bb-repo-#{SecureRandom.hex(4)}"
    project_repo = project.project_repositories.create!(
      github_repo: repo_name,
      github_installation_id: bitbucket_connections(:one).id,
      provider: "bitbucket"
    )

    payload = {
      pullrequest: {
        id: 42,
        title: "Add feature",
        description: "New feature",
        links: { html: { href: "https://bitbucket.org/#{repo_name}/pull-requests/42" } },
        merge_commit: { hash: "abc123def" },
        destination: { branch: { name: "main" } }
      },
      repository: { full_name: repo_name }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", @webhook_secret, payload)

    assert_enqueued_with(job: AnalyzePullRequestJob) do
      post webhooks_bitbucket_path,
        params: payload,
        headers: {
          "CONTENT_TYPE" => "application/json",
          "X-Hub-Signature" => signature,
          "X-Event-Key" => "pullrequest:fulfilled"
        }
    end

    assert_response :accepted
  ensure
    project_repo&.destroy
  end

  test "returns ok for push events" do
    payload = {
      repository: { full_name: "my-workspace/my-repo" },
      push: { changes: [] }
    }.to_json

    signature = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", @webhook_secret, payload)

    post webhooks_bitbucket_path,
      params: payload,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "X-Hub-Signature" => signature,
        "X-Event-Key" => "repo:push"
      }

    assert_response :ok
  end
end

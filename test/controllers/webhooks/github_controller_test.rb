require "test_helper"

class Webhooks::GithubControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @webhook_secret = @project.webhook_secret
  end

  test "returns 200 for non-pull_request events" do
    payload = { action: "push" }.to_json
    signature = generate_signature(payload, @webhook_secret)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "push",
        "X-Hub-Signature-256" => signature
      }

    assert_response :ok
  end

  test "returns 404 for unknown repository" do
    payload = {
      action: "closed",
      repository: { full_name: "unknown/repo" },
      pull_request: { merged: true, number: 1 }
    }.to_json

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => "sha256=invalid"
      }

    assert_response :not_found
  end

  test "returns 401 for invalid signature" do
    payload = {
      action: "closed",
      repository: { full_name: @project.github_repo },
      pull_request: { merged: true, number: 1 }
    }.to_json

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => "sha256=invalid_signature"
      }

    assert_response :unauthorized
  end

  test "returns 200 for non-merged pull request" do
    payload = {
      action: "closed",
      repository: { full_name: @project.github_repo },
      pull_request: { merged: false, number: 1 }
    }.to_json
    signature = generate_signature(payload, @webhook_secret)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => signature
      }

    assert_response :ok
  end

  test "returns 200 for opened pull request" do
    payload = {
      action: "opened",
      repository: { full_name: @project.github_repo },
      pull_request: { merged: false, number: 1 }
    }.to_json
    signature = generate_signature(payload, @webhook_secret)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => signature
      }

    assert_response :ok
  end

  test "enqueues job for merged pull request" do
    payload = {
      action: "closed",
      repository: { full_name: @project.github_repo },
      pull_request: {
        merged: true,
        number: 123,
        html_url: "https://github.com/#{@project.github_repo}/pull/123",
        title: "Add new feature",
        body: "This PR adds a cool feature"
      }
    }.to_json
    signature = generate_signature(payload, @webhook_secret)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => signature
      }

    assert_response :accepted
  end

  test "returns 400 for malformed JSON" do
    post webhooks_github_path,
      params: "not valid json",
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => "sha256=anything"
      }

    assert_response :bad_request
  end

  private

  def generate_signature(payload, secret)
    "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      secret,
      payload
    )
  end
end

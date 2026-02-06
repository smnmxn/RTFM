require "test_helper"

class Webhooks::GithubControllerTest < ActionDispatch::IntegrationTest
  WEBHOOK_SECRET = "test_webhook_secret_for_testing"

  setup do
    @project = projects(:one)
    # Ensure project has a project_repository so webhook lookup works
    @project_repo = @project.project_repositories.find_or_create_by!(
      github_repo: @project.github_repo,
      github_installation_id: 12345
    )
    ENV["GITHUB_APP_WEBHOOK_SECRET"] = WEBHOOK_SECRET
  end

  teardown do
    ENV.delete("GITHUB_APP_WEBHOOK_SECRET")
  end

  test "returns 200 for non-pull_request events" do
    payload = { action: "push" }.to_json
    signature = generate_signature(payload)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "push",
        "X-Hub-Signature-256" => signature
      }

    assert_response :ok
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
    signature = generate_signature(payload)

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
    signature = generate_signature(payload)

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
    signature = generate_signature(payload)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => signature
      }

    assert_response :accepted
  end

  test "returns not_found for unknown repository" do
    payload = {
      action: "closed",
      repository: { full_name: "unknown/repo" },
      pull_request: { merged: true, number: 1, html_url: "https://github.com/unknown/repo/pull/1", title: "Test", body: "" }
    }.to_json
    signature = generate_signature(payload)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => signature
      }

    assert_response :not_found
  end

  test "returns 400 for malformed JSON" do
    payload = "not valid json"
    signature = generate_signature(payload)

    post webhooks_github_path,
      params: payload,
      headers: {
        "Content-Type" => "application/json",
        "X-GitHub-Event" => "pull_request",
        "X-Hub-Signature-256" => signature
      }

    assert_response :bad_request
  end

  private

  def generate_signature(payload)
    "sha256=" + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new("sha256"),
      WEBHOOK_SECRET,
      payload
    )
  end
end

require "test_helper"

class Vcs::Bitbucket::WebhookHandlerTest < ActiveSupport::TestCase
  test "parses pullrequest:fulfilled event" do
    payload = {
      pullrequest: {
        id: 42,
        title: "Add feature",
        description: "Adds a new feature",
        links: { html: { href: "https://bitbucket.org/ws/repo/pull-requests/42" } },
        merge_commit: { hash: "abc123" },
        destination: { branch: { name: "main" } }
      },
      repository: { full_name: "my-workspace/my-repo" }
    }.to_json

    handler = Vcs::Bitbucket::WebhookHandler.new(payload: payload, event_type: "pullrequest:fulfilled")
    event = handler.process

    assert_equal :pull_request_merged, event[:action]
    assert_equal "my-workspace/my-repo", event[:repo]
    assert_equal 42, event[:pr_number]
    assert_equal "Add feature", event[:pr_title]
    assert_equal "Adds a new feature", event[:pr_body]
    assert_equal "abc123", event[:merge_commit_sha]
    assert_equal "main", event[:target_branch]
    assert_equal "https://bitbucket.org/ws/repo/pull-requests/42", event[:pr_url]
  end

  test "parses repo:push event" do
    payload = {
      repository: { full_name: "my-workspace/my-repo" },
      push: {
        changes: [
          {
            commits: [
              { hash: "abc123", message: "First commit", author: { raw: "Alice <alice@example.com>" } },
              { hash: "def456", message: "Second commit", author: { raw: "Bob <bob@example.com>" } }
            ]
          }
        ]
      }
    }.to_json

    handler = Vcs::Bitbucket::WebhookHandler.new(payload: payload, event_type: "repo:push")
    event = handler.process

    assert_equal :push, event[:action]
    assert_equal "my-workspace/my-repo", event[:repo]
    assert_equal 2, event[:commits].size
    assert_equal "abc123", event[:commits].first[:sha]
  end

  test "ignores unknown event types" do
    payload = { repository: { full_name: "ws/repo" } }.to_json

    handler = Vcs::Bitbucket::WebhookHandler.new(payload: payload, event_type: "repo:fork")
    event = handler.process

    assert_equal :ignore, event[:action]
  end
end

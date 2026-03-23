require "test_helper"

class Vcs::Bitbucket::NormalizerTest < ActiveSupport::TestCase
  test "normalizes repository data" do
    data = {
      "uuid" => "{repo-uuid}",
      "full_name" => "my-workspace/my-repo",
      "name" => "my-repo",
      "workspace" => { "slug" => "my-workspace" },
      "is_private" => true,
      "description" => "A test repo",
      "updated_on" => "2026-03-20T10:00:00Z",
      "links" => { "html" => { "href" => "https://bitbucket.org/my-workspace/my-repo" } },
      "mainbranch" => { "name" => "main" },
      "website" => "https://example.com"
    }

    connection = bitbucket_connections(:one)
    result = Vcs::Bitbucket::Normalizer.repository(data, connection)

    assert_equal "{repo-uuid}", result[:id]
    assert_equal "my-workspace/my-repo", result[:full_name]
    assert_equal "my-repo", result[:name]
    assert_equal "my-workspace", result[:owner]
    assert_equal true, result[:private]
    assert_equal "A test repo", result[:description]
    assert_equal "https://bitbucket.org/my-workspace/my-repo", result[:html_url]
    assert_equal "main", result[:default_branch]
    assert_equal "https://example.com", result[:homepage]
    assert_equal "bitbucket", result[:provider]
    assert_equal connection.id, result[:installation_id]
    assert_equal connection.workspace_slug, result[:installation_account]
  end

  test "normalizes pull request data" do
    data = {
      "id" => 42,
      "title" => "Add new feature",
      "links" => { "html" => { "href" => "https://bitbucket.org/ws/repo/pull-requests/42" } },
      "updated_on" => "2026-03-20T10:00:00Z",
      "merge_commit" => { "hash" => "abc123def456" },
      "author" => {
        "display_name" => "Alice",
        "nickname" => "alice",
        "links" => { "avatar" => { "href" => "https://avatar.example.com/alice.png" } }
      }
    }

    result = Vcs::Bitbucket::Normalizer.pull_request(data)

    assert_equal 42, result[:number]
    assert_equal "Add new feature", result[:title]
    assert_equal "https://bitbucket.org/ws/repo/pull-requests/42", result[:html_url]
    assert_equal "abc123def456", result[:merge_commit_sha]
    assert_equal "Alice", result[:user][:login]
    assert_equal "https://avatar.example.com/alice.png", result[:user][:avatar_url]
  end

  test "normalizes commit data" do
    data = {
      "hash" => "abc123def4567890",
      "message" => "Fix bug in login\n\nDetailed description",
      "date" => "2026-03-20T10:00:00Z",
      "author" => {
        "raw" => "Alice Smith <alice@example.com>",
        "user" => {
          "display_name" => "Alice Smith",
          "links" => { "avatar" => { "href" => "https://avatar.example.com/alice.png" } }
        }
      },
      "links" => { "html" => { "href" => "https://bitbucket.org/ws/repo/commits/abc123def4567890" } }
    }

    result = Vcs::Bitbucket::Normalizer.commit(data)

    assert_equal "abc123def4567890", result[:sha]
    assert_equal "abc123d", result[:short_sha]
    assert_equal "Fix bug in login\n\nDetailed description", result[:message]
    assert_equal "Fix bug in login", result[:title]
    assert_equal "2026-03-20T10:00:00Z", result[:committed_at]
    assert_equal "Alice Smith", result[:author][:login]
    assert_equal "https://avatar.example.com/alice.png", result[:author][:avatar_url]
  end
end

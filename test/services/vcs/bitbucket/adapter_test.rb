require "test_helper"

class Vcs::Bitbucket::AdapterTest < ActiveSupport::TestCase
  test "provider_name returns :bitbucket" do
    adapter = Vcs::Bitbucket::Adapter.new
    assert_equal :bitbucket, adapter.provider_name
  end

  test "clone_url uses x-token-auth format" do
    adapter = Vcs::Bitbucket::Adapter.new
    url = adapter.clone_url("my-workspace/my-repo", "fake_token")
    assert_equal "https://x-token-auth:fake_token@bitbucket.org/my-workspace/my-repo.git", url
  end

  test "web_url points to bitbucket.org" do
    adapter = Vcs::Bitbucket::Adapter.new
    url = adapter.web_url("my-workspace/my-repo")
    assert_equal "https://bitbucket.org/my-workspace/my-repo", url
  end

  test "pull_request_url uses pull-requests path" do
    adapter = Vcs::Bitbucket::Adapter.new
    url = adapter.pull_request_url("my-workspace/my-repo", 42)
    assert_equal "https://bitbucket.org/my-workspace/my-repo/pull-requests/42", url
  end

  test "commit_url points to commits path" do
    adapter = Vcs::Bitbucket::Adapter.new
    url = adapter.commit_url("my-workspace/my-repo", "abc123")
    assert_equal "https://bitbucket.org/my-workspace/my-repo/commits/abc123", url
  end

  test "verify_webhook validates HMAC signature" do
    adapter = Vcs::Bitbucket::Adapter.new
    payload = '{"test": "data"}'
    secret = "test_secret"

    valid_sig = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", secret, payload)
    assert adapter.verify_webhook(payload, valid_sig, secret)
    assert_not adapter.verify_webhook(payload, "sha256=invalid", secret)
    assert_not adapter.verify_webhook(payload, nil, secret)
    assert_not adapter.verify_webhook(payload, "", secret)
  end

  test "registered in Vcs::Provider" do
    assert Vcs::Provider.supported?(:bitbucket)
    adapter = Vcs::Provider.for(:bitbucket)
    assert_instance_of Vcs::Bitbucket::Adapter, adapter
  end

  test "raises NotFoundError for missing connection" do
    # Ensure error classes are loaded
    Vcs::Error
    adapter = Vcs::Bitbucket::Adapter.new
    assert_raises(Vcs::NotFoundError) do
      adapter.authenticate(999999)
    end
  end
end

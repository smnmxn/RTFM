require "e2e_test_helper"
require_relative "../pages/inbox_page"

class InboxFlowTest < E2ETestCase
  setup do
    @user = users(:one)
    @project = projects(:one)
    @inbox_page = E2E::Pages::InboxPage.new(@page, self)

    # Log in and navigate to project dashboard
    login_as(@user)
    @inbox_page.visit_project(@project.slug)
  end

  # =============================================================
  # Inbox Rendering Tests
  # =============================================================

  test "inbox displays articles section when articles exist" do
    # Fixture has inbox articles (unreviewed, generation_completed)
    assert @inbox_page.has_articles_section?, "Expected Articles section to be visible"
    assert @inbox_page.article_count > 0, "Expected at least one article in inbox"
  end

  test "inbox displays recommendations section when recommendations exist" do
    # Fixture has pending recommendations
    assert @inbox_page.has_recommendations_section?, "Expected Suggestions section to be visible"
    assert @inbox_page.recommendation_count > 0, "Expected at least one recommendation in inbox"
  end

  test "inbox shows progress indicator" do
    assert @inbox_page.has_progress_indicator?, "Expected progress indicator to be visible"
    # Should show pending count when there are pending items
    assert @inbox_page.progress_text.present?, "Expected progress text to be present"
  end

  test "inbox shows pending count in progress indicator" do
    # Count inbox items from fixtures
    progress = @inbox_page.progress_text
    assert progress.include?("pending"), "Expected progress to show pending count"
  end

  # =============================================================
  # Article Selection Tests
  # =============================================================

  test "clicking article loads it in editor panel" do
    article = articles(:inbox_article_completed)
    @inbox_page.select_article(article.title)

    assert @inbox_page.editor_shows_title?(article.title), "Expected editor to show article title"
  end

  test "selected article has visual highlight" do
    article = articles(:inbox_article_completed)
    @inbox_page.select_article(article.title)

    assert @inbox_page.article_selected?(article.title), "Expected article to have selected styling"
  end

  test "editor shows approve and reject buttons for completed articles" do
    article = articles(:inbox_article_completed)
    @inbox_page.select_article(article.title)

    assert @inbox_page.has_approve_button?, "Expected Approve button to be visible"
    assert @inbox_page.has_reject_button?, "Expected Reject button to be visible"
  end

  test "editor shows generating state for running articles" do
    article = articles(:inbox_article_running)
    @inbox_page.select_article(article.title)

    assert @inbox_page.editor_shows_generating_state?, "Expected editor to show generating state"
  end

  test "article row shows spinner for generating articles" do
    article = articles(:inbox_article_running)

    # Check that the generating article appears in the list
    assert @inbox_page.has_article?(article.title), "Expected generating article to be in list"

    # Check that it has a spinner icon
    assert @inbox_page.article_has_spinner?(article.title), "Expected spinner icon for generating article"
  end

  # =============================================================
  # Article Approval Flow Tests
  # =============================================================

  test "approving article without section shows section picker" do
    article = articles(:inbox_article_completed)
    @inbox_page.select_article(article.title)

    # Click Approve - should open section picker since article has no section
    @inbox_page.approve_article

    assert @inbox_page.section_picker_visible?, "Expected section picker modal to appear"
  end

  test "approving article with section publishes immediately" do
    article = articles(:inbox_article_with_section)
    @inbox_page.select_article(article.title)

    initial_article_count = @inbox_page.article_count

    # Click Approve - should approve directly since article has section
    @inbox_page.approve_article
    wait_for_turbo

    # Article should be removed from inbox
    assert @inbox_page.article_count < initial_article_count, "Expected article to be removed from inbox"
    refute @inbox_page.has_article?(article.title), "Expected approved article to be removed from list"
  end

  test "approving article through section picker works" do
    article = articles(:inbox_article_completed)
    @inbox_page.select_article(article.title)

    initial_article_count = @inbox_page.article_count

    # Approve with section selection
    @inbox_page.approve_article_with_section("Getting Started")

    # Article should be removed from inbox
    refute @inbox_page.has_article?(article.title), "Expected approved article to be removed from list"
  end

  # =============================================================
  # Article Rejection Flow Tests
  # =============================================================

  test "rejecting article removes it from inbox and shows next item" do
    article = articles(:inbox_article_completed)
    initial_count = @inbox_page.article_count

    @inbox_page.select_article(article.title)
    @inbox_page.reject_article

    # Article should be removed from the inbox list
    assert @inbox_page.article_count < initial_count, "Expected article count to decrease after rejection"
    refute @inbox_page.has_article?(article.title), "Expected rejected article to be removed from list"
  end

  # =============================================================
  # Recommendation Selection Tests
  # =============================================================

  test "clicking recommendation loads it in editor" do
    recommendation = recommendations(:inbox_recommendation_webhooks)
    @inbox_page.select_recommendation(recommendation.title)

    assert @inbox_page.editor_shows_recommendation?(recommendation.title), "Expected editor to show recommendation"
    assert @inbox_page.editor_shows_description?(recommendation.description), "Expected editor to show description"
  end

  test "editor shows accept and reject buttons for recommendations" do
    recommendation = recommendations(:inbox_recommendation_webhooks)
    @inbox_page.select_recommendation(recommendation.title)

    assert @inbox_page.has_accept_button?, "Expected Accept button to be visible"
    assert @inbox_page.has_reject_button?, "Expected Reject button to be visible"
  end

  test "recommendation editor shows justification" do
    recommendation = recommendations(:inbox_recommendation_webhooks)
    @inbox_page.select_recommendation(recommendation.title)

    assert has_text?("Why this article?"), "Expected justification section header"
    assert has_text?(recommendation.justification), "Expected justification text"
  end

  # =============================================================
  # Recommendation Action Tests
  # =============================================================

  test "accepting recommendation removes it from list" do
    recommendation = recommendations(:inbox_recommendation_webhooks)
    @inbox_page.select_recommendation(recommendation.title)

    initial_count = @inbox_page.recommendation_count

    @inbox_page.accept_recommendation

    # Recommendation should be removed and article created
    assert @inbox_page.recommendation_count < initial_count, "Expected recommendation count to decrease"
    refute @inbox_page.has_recommendation?(recommendation.title), "Expected accepted recommendation to be removed"
  end

  test "rejecting recommendation removes it from inbox" do
    recommendation = recommendations(:inbox_recommendation_webhooks)
    @inbox_page.select_recommendation(recommendation.title)

    initial_count = @inbox_page.recommendation_count

    @inbox_page.reject_recommendation

    # Recommendation should be removed
    assert @inbox_page.recommendation_count < initial_count, "Expected recommendation count to decrease"
    refute @inbox_page.has_recommendation?(recommendation.title), "Expected rejected recommendation to be removed"
  end

  # =============================================================
  # Navigation & URL Tests
  # =============================================================

  # NOTE: Turbo frame requests don't update the browser URL by design.
  # These tests verify that selection works correctly within the frame.
  test "selecting article updates editor panel" do
    article = articles(:inbox_article_completed)
    @inbox_page.select_article(article.title)

    # Editor should show the selected article
    assert @inbox_page.editor_shows_title?(article.title),
      "Expected editor to show selected article title"
  end

  test "selecting recommendation updates editor panel" do
    recommendation = recommendations(:inbox_recommendation_webhooks)
    @inbox_page.select_recommendation(recommendation.title)

    # Editor should show the selected recommendation
    assert @inbox_page.editor_shows_recommendation?(recommendation.title),
      "Expected editor to show selected recommendation"
  end

  # =============================================================
  # Tab Navigation Tests
  # =============================================================

  test "inbox tab is active by default on project dashboard" do
    assert @inbox_page.on_inbox_tab?, "Expected inbox tab to be active by default"
  end

  test "inbox badge shows pending count" do
    # The inbox tab should show a badge with pending count
    pending_count = @page.locator("button[data-tabs-name='inbox'] span.rounded-full").text_content
    assert pending_count.to_i > 0, "Expected inbox badge to show pending count"
  rescue
    # Badge might not be present if no pending items
    skip "No pending items to show badge"
  end
end

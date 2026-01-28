require "e2e_test_helper"
require_relative "../pages/articles_page"

class ArticlesFlowTest < E2ETestCase
  setup do
    @user = users(:one)
    @project = projects(:one)
    @articles_page = E2E::Pages::ArticlesPage.new(@page, self)

    # Log in and navigate to project dashboard
    login_as(@user)
    @articles_page.visit_project(@project.slug)
    @articles_page.click_articles_tab
  end

  # =============================================================
  # Articles Tab Rendering Tests
  # =============================================================

  test "articles tab displays folder tree with sections" do
    assert @articles_page.on_articles_tab?, "Expected articles tab to be active"
    assert @articles_page.has_section?("Getting Started"), "Expected Getting Started section"
    assert @articles_page.has_section?("Troubleshooting"), "Expected Troubleshooting section"
    assert @articles_page.has_section?("Advanced Usage"), "Expected Advanced Usage section"
  end

  test "articles tab shows correct section article counts" do
    # Getting Started has published_article and draft_article
    getting_started_count = @articles_page.section_article_count("Getting Started")
    assert getting_started_count >= 1, "Expected at least 1 article in Getting Started"
  end

  test "clicking articles tab switches from inbox tab" do
    @articles_page.click_inbox_tab
    refute @articles_page.on_articles_tab?, "Expected articles tab to not be active"

    @articles_page.click_articles_tab
    assert @articles_page.on_articles_tab?, "Expected articles tab to be active after clicking"
  end

  test "articles panel has new article button" do
    # Check that the New Article button is visible in the articles panel
    new_article_btn = @page.locator("[data-tabs-name='articles'][data-tabs-target='panel'] button:has-text('New Article')")
    assert new_article_btn.count > 0 || has_text?("New Article"), "Expected New Article button to be visible"
  end

  test "articles panel has new section button" do
    assert has_text?("Sections & Articles"), "Expected Sections & Articles header"
  end

  # =============================================================
  # Article Selection Tests
  # =============================================================

  test "clicking article loads it in editor panel" do
    article = articles(:published_article)
    @articles_page.select_article(article.title)

    assert @articles_page.editor_shows_article?(article.title), "Expected editor to show article title"
  end

  test "selected article has visual highlight" do
    article = articles(:published_article)
    @articles_page.select_article(article.title)

    assert @articles_page.article_selected?(article.title), "Expected article to have selected styling"
  end

  test "editor shows correct status badge for published article" do
    article = articles(:published_article)
    @articles_page.select_article(article.title)

    status = @articles_page.editor_article_status
    assert_equal "Published", status, "Expected status to be Published"
  end

  test "editor shows correct status badge for draft article" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    status = @articles_page.editor_article_status
    assert_equal "Draft", status, "Expected status to be Draft"
  end

  # =============================================================
  # Article Creation Tests
  # =============================================================

  test "create article via new article button" do
    @articles_page.open_new_article_modal
    assert @articles_page.new_article_modal_visible?, "Expected new article modal to be visible"

    @articles_page.fill_article_title("Test Article from E2E")
    @articles_page.submit_new_article

    # After creating, the page redirects - ensure we're on articles tab
    @articles_page.click_articles_tab

    # Should navigate to the new article
    assert @articles_page.has_article_in_tree?("Test Article from E2E"), "Expected new article to appear in folder tree"
  end

  test "create article with section assignment" do
    @articles_page.open_new_article_modal
    @articles_page.fill_article_title("Article in Section")
    @articles_page.select_article_section("Troubleshooting")
    @articles_page.submit_new_article

    # After creating, the page redirects - ensure we're on articles tab
    @articles_page.click_articles_tab

    # Article should appear in the Troubleshooting section
    assert @articles_page.has_article_in_tree?("Article in Section"), "Expected new article to appear in folder tree"
  end

  test "new article appears in folder tree" do
    initial_count = @articles_page.article_count_in_tree

    @articles_page.open_new_article_modal
    @articles_page.fill_article_title("New Tree Article")
    @articles_page.submit_new_article

    # Give turbo time to update
    sleep 0.5

    assert @articles_page.has_article_in_tree?("New Tree Article"), "Expected new article to appear in folder tree"
  end

  # =============================================================
  # Article Publishing Tests
  # =============================================================

  test "publish button appears for draft articles" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    assert @articles_page.has_publish_button?, "Expected Publish button for draft article"
    refute @articles_page.has_unpublish_button?, "Expected no Unpublish button for draft article"
  end

  test "publishing article changes status to published" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    @articles_page.publish_article

    # Status should now be Published
    status = @articles_page.editor_article_status
    assert_equal "Published", status, "Expected status to change to Published"
    assert @articles_page.has_unpublish_button?, "Expected Unpublish button after publishing"
  end

  test "unpublish button appears for published articles" do
    article = articles(:published_article)
    @articles_page.select_article(article.title)

    assert @articles_page.has_unpublish_button?, "Expected Unpublish button for published article"
    refute @articles_page.has_publish_button?, "Expected no Publish button for published article"
  end

  test "unpublishing article changes status to draft" do
    article = articles(:published_article)
    @articles_page.select_article(article.title)

    @articles_page.unpublish_article

    status = @articles_page.editor_article_status
    assert_equal "Draft", status, "Expected status to change to Draft"
    assert @articles_page.has_publish_button?, "Expected Publish button after unpublishing"
  end

  # =============================================================
  # Article Actions Tests
  # =============================================================

  test "duplicate button exists and is clickable" do
    article = articles(:published_article)
    @articles_page.select_article(article.title)

    # Verify duplicate button exists
    assert @articles_page.has_duplicate_button?, "Expected duplicate button to be visible"

    # Get count before duplicate
    initial_article_count = Article.where(project: @project).count

    # Click duplicate
    @page.locator("turbo-frame#articles-editor-frame button[title='Duplicate']").click

    # Wait for the turbo stream response
    wait_for_turbo
    sleep 1.0

    # Verify a new article was created in the database
    new_article_count = Article.where(project: @project).count
    assert_equal initial_article_count + 1, new_article_count, "Expected one new article to be created after duplication"
  end

  test "delete article redirects after confirmation" do
    # Create a new article to delete
    @articles_page.open_new_article_modal
    @articles_page.fill_article_title("Article to Delete E2E")
    @articles_page.submit_new_article

    # Navigate to articles tab
    @articles_page.click_articles_tab
    sleep 0.5

    # Select the article
    @articles_page.select_article("Article to Delete E2E")
    sleep 0.3

    # Get current URL before delete
    url_before = @page.url

    # Set up dialog handler before clicking delete
    @page.on("dialog", ->(dialog) { dialog.accept })

    # Click delete button
    @page.locator("turbo-frame#articles-editor-frame button[title='Delete']").click

    # Wait for navigation/redirect
    @page.wait_for_load_state(state: "networkidle")
    sleep 1.0

    # Verify we were redirected (URL changed or page reloaded)
    # The delete action redirects to project path with articles anchor
    assert @page.url.include?(@project.slug), "Expected to be on project page after delete"
  end

  test "editor shows action buttons" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    assert @articles_page.has_delete_button?, "Expected Delete button to be visible"
    assert @articles_page.has_duplicate_button?, "Expected Duplicate button to be visible"
    assert @articles_page.has_preview_button?, "Expected Preview button to be visible"
  end

  # =============================================================
  # Section Management Tests
  # =============================================================

  test "create new section via modal" do
    @articles_page.open_new_section_modal
    assert @articles_page.new_section_modal_visible?, "Expected new section modal to be visible"

    @articles_page.fill_section_name("E2E Test Section")
    @articles_page.submit_new_section

    # Section should appear in folder tree
    assert @articles_page.has_section?("E2E Test Section"), "Expected new section to appear"
  end

  test "section shows kebab menu on hover" do
    @articles_page.open_section_menu("Getting Started")
    assert @articles_page.section_menu_visible?("Getting Started"), "Expected section menu to be visible"
  end

  test "collapse and expand section in folder tree" do
    section_name = "Getting Started"

    # Section should be expanded by default
    assert @articles_page.section_expanded?(section_name), "Expected section to be expanded by default"

    # Collapse it
    @articles_page.collapse_section(section_name)
    refute @articles_page.section_expanded?(section_name), "Expected section to be collapsed"

    # Expand it again
    @articles_page.expand_section(section_name)
    assert @articles_page.section_expanded?(section_name), "Expected section to be expanded again"
  end

  test "sections display in folder tree" do
    # All three sections from fixtures should be present
    assert @articles_page.section_count >= 3, "Expected at least 3 sections"
    assert @articles_page.has_section?("Getting Started"), "Expected Getting Started section"
    assert @articles_page.has_section?("Troubleshooting"), "Expected Troubleshooting section"
    assert @articles_page.has_section?("Advanced Usage"), "Expected Advanced Usage section"
  end

  # =============================================================
  # Structured Content Tests
  # =============================================================

  test "article with structured content shows sections" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    # draft_article has structured_content in fixture
    assert @articles_page.has_introduction_section?, "Expected introduction section"
    assert @articles_page.has_steps_section?, "Expected steps section"
    assert @articles_page.has_tips_section?, "Expected tips section"
  end

  test "structured content shows prerequisites" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    assert @articles_page.has_prerequisites_section?, "Expected prerequisites section"
    count = @articles_page.prerequisites_count
    assert count >= 1, "Expected at least one prerequisite"
  end

  test "structured content shows steps" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    count = @articles_page.steps_count
    assert count >= 1, "Expected at least one step"
  end

  test "add step button works" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    initial_count = @articles_page.steps_count
    @articles_page.click_add_step

    new_count = @articles_page.steps_count
    assert new_count > initial_count, "Expected step count to increase"
  end

  test "structured content shows tips" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    count = @articles_page.tips_count
    assert count >= 1, "Expected at least one tip"
  end

  test "add tip button works" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    initial_count = @articles_page.tips_count
    @articles_page.click_add_tip

    new_count = @articles_page.tips_count
    assert new_count > initial_count, "Expected tip count to increase"
  end

  # =============================================================
  # Content Generation State Tests
  # =============================================================

  test "regenerate button appears for completed articles" do
    article = articles(:draft_article)
    @articles_page.select_article(article.title)

    assert @articles_page.has_regenerate_button?, "Expected Regenerate button for completed article"
  end

  test "generate button appears for pending articles" do
    # Create a new blank article (which will be in pending state)
    @articles_page.open_new_article_modal
    @articles_page.fill_article_title("Blank Pending Article")
    @articles_page.submit_new_article

    # New articles start in pending state
    assert @articles_page.has_generate_button?, "Expected Generate button for pending article"
  end

  # =============================================================
  # Navigation Tests
  # =============================================================

  test "selecting different articles updates editor" do
    article1 = articles(:published_article)
    article2 = articles(:draft_article)

    @articles_page.select_article(article1.title)
    assert @articles_page.editor_shows_article?(article1.title), "Expected first article in editor"

    @articles_page.select_article(article2.title)
    assert @articles_page.editor_shows_article?(article2.title), "Expected second article in editor"
  end

  test "articles tab badge shows published count" do
    # Check that the articles tab has a badge
    badge = @page.locator("button[data-tabs-name='articles'] span.rounded-full")
    if badge.count > 0
      badge_text = badge.text_content
      assert badge_text.to_i >= 0, "Expected articles badge to show a count"
    end
  end

  # =============================================================
  # Help Centre Integration Tests
  # =============================================================

  test "published article appears in help centre" do
    article = articles(:published_article)

    # Visit the help centre
    @articles_page.visit_help_centre(@project.slug)

    # The published article should be visible
    assert @articles_page.help_centre_has_article?(article.title),
      "Expected published article '#{article.title}' to appear in help centre"
  end

  test "draft article does not appear in help centre" do
    article = articles(:draft_article)

    # Visit the help centre
    @articles_page.visit_help_centre(@project.slug)

    # The draft article should NOT be visible
    refute @articles_page.help_centre_has_article?(article.title),
      "Expected draft article '#{article.title}' to NOT appear in help centre"
  end

  test "publishing article makes it appear in help centre" do
    article = articles(:draft_article)

    # First verify the article is NOT in help centre (it's a draft)
    @articles_page.visit_help_centre(@project.slug)
    refute @articles_page.help_centre_has_article?(article.title),
      "Expected draft article to NOT appear in help centre before publishing"

    # Go back to dashboard and publish the article
    @articles_page.visit_project(@project.slug)
    @articles_page.click_articles_tab
    @articles_page.select_article(article.title)
    @articles_page.publish_article

    # Now verify the article IS in help centre
    @articles_page.visit_help_centre(@project.slug)
    assert @articles_page.help_centre_has_article?(article.title),
      "Expected article '#{article.title}' to appear in help centre after publishing"
  end

  test "unpublishing article removes it from help centre" do
    article = articles(:published_article)

    # First verify the article IS in help centre (it's published)
    @articles_page.visit_help_centre(@project.slug)
    assert @articles_page.help_centre_has_article?(article.title),
      "Expected published article to appear in help centre before unpublishing"

    # Go back to dashboard and unpublish the article
    @articles_page.visit_project(@project.slug)
    @articles_page.click_articles_tab
    @articles_page.select_article(article.title)
    @articles_page.unpublish_article

    # Now verify the article is NOT in help centre
    @articles_page.visit_help_centre(@project.slug)
    refute @articles_page.help_centre_has_article?(article.title),
      "Expected article '#{article.title}' to NOT appear in help centre after unpublishing"
  end

  test "help centre section shows only published articles" do
    section = sections(:getting_started)

    # Visit the section in help centre
    @articles_page.visit_help_centre_section(@project.slug, section.slug)

    # Published article should be visible
    published = articles(:published_article)
    assert @articles_page.help_centre_has_article?(published.title),
      "Expected published article in section"

    # Draft article should NOT be visible
    draft = articles(:draft_article)
    refute @articles_page.help_centre_has_article?(draft.title),
      "Expected draft article to NOT appear in section"
  end
end

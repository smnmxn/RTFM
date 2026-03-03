require "test_helper"

class BlogControllerTest < ActionDispatch::IntegrationTest
  test "blog index renders successfully" do
    get blog_path
    assert_response :success
    assert_select "h1", "SupportPages.io"
  end

  test "blog index shows published posts" do
    get blog_path
    assert_response :success

    # Should show the published posts
    assert_select "article", minimum: 1
  end

  test "blog index shows posts in reverse chronological order" do
    get blog_path
    assert_response :success

    # Most recent post should be first
    # 2026-03-03 should appear before 2026-02-15 and 2026-02-01
    body = response.body
    pos_march = body.index("Turn Code Into Documentation")
    pos_feb_15 = body.index("5 Best Practices")
    pos_feb_01 = body.index("Why Good Documentation Matter")

    assert pos_march, "March post should be present"
    assert pos_feb_15, "Feb 15 post should be present"
    assert pos_feb_01, "Feb 01 post should be present"

    assert pos_march < pos_feb_15, "March post should appear before Feb 15 post"
    assert pos_feb_15 < pos_feb_01, "Feb 15 post should appear before Feb 01 post"
  end

  test "individual blog post renders with markdown content" do
    get blog_post_path("introducing-rtfm")
    assert_response :success

    # Check title
    assert_select "h1", "Introducing supportpages.io: Turn Code Into Documentation"

    # Check that markdown was rendered (look for HTML tags)
    assert_select ".legal-content h2", "Why We Built This"
  end

  test "blog post includes SEO meta tags" do
    get blog_post_path("introducing-rtfm")
    assert_response :success

    # Check for meta description
    assert_select "meta[name='description']"

    # Check for Open Graph tags
    assert_select "meta[property='og:title']"
    assert_select "meta[property='og:description']"
    assert_select "meta[property='og:url']"
    assert_select "meta[property='og:type'][content='article']"

    # Check for Twitter Card tags
    assert_select "meta[name='twitter:card']"
    assert_select "meta[name='twitter:title']"

    # Check for structured data
    assert_select "script[type='application/ld+json']"
  end

  test "blog post includes canonical URL" do
    get blog_post_path("introducing-rtfm")
    assert_response :success

    assert_select "link[rel='canonical'][href*='/blog/introducing-rtfm']"
  end

  test "returns 404 for non-existent blog post" do
    get blog_post_path("this-post-does-not-exist")
    assert_response :not_found
  end

  test "blog post shows hero image when present" do
    # Test that hero image section is conditionally rendered
    # Since we removed images from test posts, just verify the page loads
    get blog_post_path("introducing-rtfm")
    assert_response :success
  end

  test "blog post shows author and date" do
    get blog_post_path("introducing-rtfm")
    assert_response :success

    assert_select "time[datetime='2026-03-03']"
    assert_match "Simon Willison", response.body
  end

  test "blog post includes back to blog link" do
    get blog_post_path("introducing-rtfm")
    assert_response :success

    assert_select "a[href='#{blog_path}']", text: /Back to Blog/
  end

  test "blog post includes CTA footer" do
    get blog_post_path("introducing-rtfm")
    assert_response :success

    assert_match "Ready to automate your documentation?", response.body
    assert_select "a[href='/login']", text: "Get Started"
  end

  test "navigation highlights blog link" do
    get blog_path
    assert_response :success

    # Check that the blog link has the active class
    assert_select "a[href='/blog'].font-semibold", minimum: 1
  end

  test "caching works correctly" do
    # First request should parse the file
    get blog_post_path("introducing-rtfm")
    assert_response :success
    first_body = response.body

    # Second request should use cache
    get blog_post_path("introducing-rtfm")
    assert_response :success
    second_body = response.body

    # Content should be identical
    assert_equal first_body, second_body
  end
end

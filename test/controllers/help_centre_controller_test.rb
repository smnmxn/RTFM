require "test_helper"

class HelpCentreControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = projects(:one)
    @article = articles(:published_article)
    @section = sections(:getting_started)

    # Set host to project subdomain for routing
    # Only use the hostname (no port) — request.host strips port anyway,
    # and parallel test processes use random ports that don't match config
    base = Rails.application.config.x.base_domain.split(":").first
    host! "#{@project.subdomain}.#{base}"
  end

  # ========================================
  # Index page meta tags
  # ========================================

  test "index has meta description from project tagline" do
    get "/"
    assert_response :success
    assert_select 'meta[name="description"]' do |elements|
      assert elements.first["content"].include?("How can we help you")
    end
  end

  test "index has Open Graph tags" do
    get "/"
    assert_response :success
    assert_select 'meta[property="og:title"]'
    assert_select 'meta[property="og:url"]'
    assert_select 'meta[property="og:type"][content="website"]'
    assert_select 'meta[property="og:site_name"][content=?]', @project.name
  end

  test "index has Twitter Card tags" do
    get "/"
    assert_response :success
    assert_select 'meta[name="twitter:card"]'
    assert_select 'meta[name="twitter:title"]'
  end

  test "index has canonical URL" do
    get "/"
    assert_response :success
    assert_select 'link[rel="canonical"]' do |elements|
      href = elements.first["href"]
      assert href.include?(@project.subdomain)
    end
  end

  test "index is indexable by default" do
    get "/"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0
  end

  # ========================================
  # Article page meta tags
  # ========================================

  test "article has meta description from content" do
    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'meta[name="description"]' do |elements|
      assert elements.first["content"].present?
    end
  end

  test "article has og:type article" do
    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'meta[property="og:type"][content="article"]'
  end

  test "article has JSON-LD structured data" do
    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'script[type="application/ld+json"]' do |elements|
      json = JSON.parse(elements.first.text)
      assert_equal "Article", json["@type"]
      assert_equal @article.title, json["headline"]
    end
  end

  test "article has canonical URL with full path" do
    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'link[rel="canonical"]' do |elements|
      href = elements.first["href"]
      assert href.include?("/#{@section.slug}/#{@article.slug}")
    end
  end

  # ========================================
  # Section page meta tags
  # ========================================

  test "section has meta description from section description" do
    get "/#{@section.slug}"
    assert_response :success
    assert_select 'meta[name="description"]' do |elements|
      content = elements.first["content"]
      # Description should contain the beginning of the section description
      assert content.include?("Set up and configure"), "Expected description to include section description text, got: #{content}"
    end
  end

  # ========================================
  # Ask page
  # ========================================

  test "ask page is always noindex" do
    get "/ask", params: { q: "how do I test?" }
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'
  end

  # ========================================
  # SEO indexing toggle (critical safety tests)
  # ========================================

  test "all pages are noindex when seo_indexing_enabled is false" do
    @project.update!(branding: @project.branding.merge("seo_indexing_enabled" => "0"))

    # Index page
    get "/"
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'

    # Article page
    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'

    # Section page
    get "/#{@section.slug}"
    assert_response :success
    assert_select 'meta[name="robots"][content="noindex, nofollow"]'
  end

  test "all pages are indexable when seo_indexing_enabled is true" do
    @project.update!(branding: @project.branding.merge("seo_indexing_enabled" => "1"))

    get "/"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0

    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0

    get "/#{@section.slug}"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0
  end

  test "all pages are indexable when seo_indexing_enabled is nil (default)" do
    # Ensure seo_indexing_enabled is not set
    branding = @project.branding.except("seo_indexing_enabled")
    @project.update!(branding: branding)

    get "/"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0

    get "/#{@section.slug}/#{@article.slug}"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0

    get "/#{@section.slug}"
    assert_response :success
    assert_select 'meta[name="robots"]', count: 0
  end
end

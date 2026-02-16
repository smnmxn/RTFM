require "test_helper"

class SeoHelperTest < ActionView::TestCase
  include SeoHelper

  # meta_description tests

  test "meta_description truncates long text to 155 characters" do
    long_text = "A" * 200
    result = meta_description(long_text)
    assert result.length <= 155
    assert result.end_with?("...")
  end

  test "meta_description strips HTML tags" do
    html = "<p>Hello <strong>world</strong> and <em>goodbye</em></p>"
    result = meta_description(html)
    assert_equal "Hello world and goodbye", result
  end

  test "meta_description strips markdown formatting" do
    markdown = "# Heading with **bold** and _italic_ and `code` and [link](http://example.com)"
    result = meta_description(markdown)
    assert_not_includes result, "#"
    assert_not_includes result, "**"
    assert_not_includes result, "_"
    assert_not_includes result, "`"
    assert_not_includes result, "[link](http://example.com)"
    assert_includes result, "link"
  end

  test "meta_description returns empty string for nil input" do
    assert_equal "", meta_description(nil)
  end

  test "meta_description returns empty string for blank input" do
    assert_equal "", meta_description("")
    assert_equal "", meta_description("   ")
  end

  test "meta_description squishes whitespace" do
    text = "Hello   world\n\nand   goodbye"
    result = meta_description(text)
    assert_equal "Hello world and goodbye", result
  end

  # seo_indexing_enabled? tests on Project model

  test "seo_indexing_enabled? returns true when nil (default)" do
    project = projects(:one)
    project.seo_indexing_enabled = nil
    assert project.seo_indexing_enabled?
  end

  test "seo_indexing_enabled? returns true when set to 1" do
    project = projects(:one)
    project.seo_indexing_enabled = "1"
    assert project.seo_indexing_enabled?
  end

  test "seo_indexing_enabled? returns true when set to true" do
    project = projects(:one)
    project.seo_indexing_enabled = true
    assert project.seo_indexing_enabled?
  end

  test "seo_indexing_enabled? returns false when set to 0" do
    project = projects(:one)
    project.seo_indexing_enabled = "0"
    assert_not project.seo_indexing_enabled?
  end

  test "seo_indexing_enabled? returns false when set to false string" do
    project = projects(:one)
    project.seo_indexing_enabled = "false"
    assert_not project.seo_indexing_enabled?
  end

  test "seo_indexing_enabled? returns false when set to false" do
    project = projects(:one)
    project.seo_indexing_enabled = false
    assert_not project.seo_indexing_enabled?
  end
end

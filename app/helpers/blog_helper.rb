module BlogHelper
  def blog_meta_tags(post)
    tags = []

    # Basic SEO
    if post[:description].present?
      tags << tag.meta(name: "description", content: post[:description])
    end

    if post[:keywords].present?
      tags << tag.meta(name: "keywords", content: post[:keywords])
    end

    canonical_url = blog_post_url(post[:slug])
    tags << tag.link(rel: "canonical", href: canonical_url)

    # Open Graph
    tags << tag.meta(property: "og:title", content: post[:title])
    tags << tag.meta(property: "og:description", content: post[:description]) if post[:description].present?
    tags << tag.meta(property: "og:url", content: canonical_url)
    tags << tag.meta(property: "og:type", content: "article")

    if post[:image].present?
      image_url = post[:image].start_with?("http") ? post[:image] : "#{request.base_url}#{post[:image]}"
      tags << tag.meta(property: "og:image", content: image_url)
    end

    if post[:date].present?
      tags << tag.meta(property: "article:published_time", content: post[:date].iso8601)
    end

    if post[:author].present?
      tags << tag.meta(property: "article:author", content: post[:author])
    end

    # Twitter Cards
    tags << tag.meta(name: "twitter:card", content: "summary_large_image")
    tags << tag.meta(name: "twitter:title", content: post[:title])
    tags << tag.meta(name: "twitter:description", content: post[:description]) if post[:description].present?

    if post[:image].present?
      image_url = post[:image].start_with?("http") ? post[:image] : "#{request.base_url}#{post[:image]}"
      tags << tag.meta(name: "twitter:image", content: image_url)
    end

    safe_join(tags, "\n")
  end

  def structured_data_for_article(post)
    data = {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": post[:title],
      "description": post[:description],
      "datePublished": post[:date]&.iso8601,
      "dateModified": post[:file_mtime]&.iso8601,
      "author": {
        "@type": "Person",
        "name": post[:author] || "supportpages.io"
      },
      "publisher": {
        "@type": "Organization",
        "name": "supportpages.io",
        "logo": {
          "@type": "ImageObject",
          "url": "#{request.base_url}/icon.png"
        }
      }
    }

    if post[:image].present?
      data[:image] = post[:image].start_with?("http") ? post[:image] : "#{request.base_url}#{post[:image]}"
    end

    tag.script(JSON.pretty_generate(data), type: "application/ld+json").html_safe
  end
end

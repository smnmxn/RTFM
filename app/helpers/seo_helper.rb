module SeoHelper
  def meta_description(text)
    return "" if text.blank?

    # Strip HTML tags
    plain = strip_tags(text.to_s)
    # Strip markdown formatting
    plain = plain.gsub(/[#*_`]/, "")
    plain = plain.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')
    # Squish whitespace
    plain = plain.squish
    # Truncate to 155 chars
    truncate(plain, length: 155, omission: "...")
  end

  def canonical_url
    if @project.custom_domain_active?
      "https://#{@project.custom_domain}#{request.path}"
    else
      "#{project_help_centre_url(@project)}#{request.path == "/" ? "" : request.path}"
    end
  end

  def seo_image_url
    @project.logo.attached? ? url_for(@project.logo) : nil
  end

  def seo_meta_tags
    title = content_for(:title).presence || "#{@project.name} #{@project.help_centre_title_or_default}"
    description = content_for(:meta_description).presence
    og_type = content_for(:og_type).presence || "website"
    image = seo_image_url
    url = canonical_url
    noindex = content_for?(:noindex) || !@project.seo_indexing_enabled?

    tags = []
    tags << tag.meta(name: "description", content: description) if description.present?
    tags << tag.meta(name: "robots", content: "noindex, nofollow") if noindex
    tags << tag.link(rel: "canonical", href: url)

    # Open Graph
    tags << tag.meta(property: "og:title", content: title)
    tags << tag.meta(property: "og:description", content: description) if description.present?
    tags << tag.meta(property: "og:url", content: url)
    tags << tag.meta(property: "og:type", content: og_type)
    tags << tag.meta(property: "og:site_name", content: @project.name)
    tags << tag.meta(property: "og:image", content: image) if image.present?

    # Twitter Card
    tags << tag.meta(name: "twitter:card", content: image.present? ? "summary_large_image" : "summary")
    tags << tag.meta(name: "twitter:title", content: title)
    tags << tag.meta(name: "twitter:description", content: description) if description.present?
    tags << tag.meta(name: "twitter:image", content: image) if image.present?

    safe_join(tags, "\n    ")
  end

  def article_json_ld(article, project)
    data = {
      "@context" => "https://schema.org",
      "@type" => "Article",
      "headline" => article.title,
      "url" => canonical_url,
      "datePublished" => article.published_at&.iso8601,
      "dateModified" => article.updated_at&.iso8601,
      "publisher" => {
        "@type" => "Organization",
        "name" => project.name
      }
    }

    description = meta_description(article.introduction.presence || article.content)
    data["description"] = description if description.present?

    if project.logo.attached?
      data["publisher"]["logo"] = {
        "@type" => "ImageObject",
        "url" => url_for(project.logo)
      }
    end

    tag.script(data.to_json.html_safe, type: "application/ld+json")
  end
end

module ApplicationHelper
  # Help Centre URL helpers - uses subdomain when configured
  def project_help_centre_url(project)
    base_domain = Rails.application.config.x.base_domain
    protocol = Rails.env.production? ? "https" : "http"
    subdomain = project.effective_subdomain

    "#{protocol}://#{subdomain}.#{base_domain}"
  end

  def project_help_centre_article_url(project, article)
    "#{project_help_centre_url(project)}/#{article.section.slug}/#{article.slug}"
  end

  def markdown(text)
    return "" if text.blank?

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener" }
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      fenced_code_blocks: true,
      tables: true,
      strikethrough: true,
      highlight: true,
      no_intra_emphasis: true
    )

    markdown.render(text).html_safe
  end

  def section_type_badge_class(section)
    case section.section_type
    when "template"
      "bg-blue-100 text-blue-800"
    when "ai_generated"
      "bg-purple-100 text-purple-800"
    when "custom"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end

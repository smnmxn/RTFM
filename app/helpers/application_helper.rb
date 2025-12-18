module ApplicationHelper
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

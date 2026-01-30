class LegalController < ApplicationController
  skip_before_action :require_authentication
  layout "legal"

  DOCUMENTS = {
    "privacy" => {
      file: "privacy-policy.md",
      title: "Privacy Policy",
      description: "How we collect, use, and protect your data"
    },
    "terms" => {
      file: "terms-of-service.md",
      title: "Terms of Service",
      description: "Rules for using supportpages.io"
    },
    "dpa" => {
      file: "dpa.md",
      title: "Data Processing Agreement",
      description: "GDPR-compliant agreement for business customers"
    },
    "subprocessors" => {
      file: "subprocessors.md",
      title: "Sub-processors",
      description: "Third-party services we use to operate"
    },
    "security" => {
      file: "security.md",
      title: "Security Overview",
      description: "How we protect your code and data"
    }
  }.freeze

  def index
    @documents = DOCUMENTS
  end

  def privacy
    render_document("privacy")
  end

  def terms
    render_document("terms")
  end

  def dpa
    render_document("dpa")
  end

  def subprocessors
    render_document("subprocessors")
  end

  def security
    render_document("security")
  end

  private

  def render_document(key)
    doc = DOCUMENTS[key]
    @title = doc[:title]
    @content = render_markdown(doc[:file])
    render :show
  end

  def render_markdown(filename)
    path = Rails.root.join("docs", "legal", filename)
    markdown = File.read(path)

    renderer = Redcarpet::Render::HTML.new(
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )

    parser = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      highlight: true,
      no_intra_emphasis: true
    )

    parser.render(markdown).html_safe
  end
end

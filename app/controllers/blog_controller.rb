class BlogController < ApplicationController
  include Trackable

  skip_before_action :require_authentication
  layout "legal"

  def index
    @nav_active = "blog"
    @posts = all_blog_posts.select { |post| show_post?(post) }
                           .sort_by { |post| post[:date] }
                           .reverse
  end

  def show
    @nav_active = "blog"
    slug = params[:slug]
    @post = all_blog_posts.find { |post| post[:slug] == slug }

    if @post.nil? || !show_post?(@post)
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end
  end

  private

  def all_blog_posts
    @all_blog_posts ||= begin
      blog_dir = Rails.root.join("docs", "blog")
      return [] unless Dir.exist?(blog_dir)

      Dir.glob(blog_dir.join("*.md")).map do |file_path|
        parse_blog_post(file_path)
      end.compact
    end
  end

  def parse_blog_post(file_path)
    cache_key = "blog_post:#{file_path}:#{File.mtime(file_path).to_i}"

    Rails.cache.fetch(cache_key) do
      content = File.read(file_path)

      # Manual frontmatter parsing to avoid Psych::DisallowedClass errors
      if content =~ /\A---\s*\n(.*?)\n---\s*\n(.*)/m
        frontmatter_yaml = $1
        markdown_content = $2

        # Parse YAML with permitted classes
        frontmatter = YAML.safe_load(frontmatter_yaml, permitted_classes: [ Date, Time, Symbol ], aliases: true)
      else
        frontmatter = {}
        markdown_content = content
      end

      filename = File.basename(file_path, ".md")
      # Extract date prefix (YYYY-MM-DD-slug or just slug)
      slug = filename.sub(/^\d{4}-\d{2}-\d{2}-/, "")

      {
        slug: slug,
        title: frontmatter["title"],
        date: frontmatter["date"] ? Date.parse(frontmatter["date"].to_s) : nil,
        author: frontmatter["author"],
        excerpt: frontmatter["excerpt"],
        description: frontmatter["description"],
        keywords: frontmatter["keywords"],
        published: frontmatter["published"],
        image: frontmatter["image"],
        content: markdown_content,
        html_content: render_markdown(markdown_content),
        file_path: file_path,
        file_mtime: File.mtime(file_path)
      }
    end
  rescue => e
    Rails.logger.error("Error parsing blog post #{file_path}: #{e.message}")
    nil
  end

  def render_markdown(markdown)
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

  def show_post?(post)
    # In production, hide unpublished posts
    # In dev/test, show all posts
    Rails.env.production? ? post[:published] == true : true
  end
end

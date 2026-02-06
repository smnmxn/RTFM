require_relative "base_page"

module E2E
  module Pages
    class HelpCentrePage < BasePage
      # =====================
      # Navigation
      # =====================

      def visit_index(project_slug)
        page.goto("#{test_case.send(:base_url)}/test/help_centre/#{project_slug}")
        wait_for_turbo
        self
      end

      def visit_section(project_slug, section_slug)
        page.goto("#{test_case.send(:base_url)}/test/help_centre/#{project_slug}/#{section_slug}")
        wait_for_turbo
        self
      end

      def visit_article(project_slug, section_slug, article_slug)
        page.goto("#{test_case.send(:base_url)}/test/help_centre/#{project_slug}/#{section_slug}/#{article_slug}")
        wait_for_turbo
        self
      end

      # =====================
      # Index Page
      # =====================

      def has_hero?
        # The hero is rendered via content_for :hero in the layout.
        # It lives in a div with a linear-gradient background.
        page.locator("div[style*='linear-gradient'] h1").visible?
      rescue
        false
      end

      def hero_title
        # The hero h1 is inside the gradient background div, distinct from the header h1
        page.locator("div[style*='linear-gradient'] h1").text_content.strip
      rescue
        nil
      end

      def hero_tagline
        # The tagline is the p tag inside the hero gradient div
        page.locator("div[style*='linear-gradient'] p").first.text_content.strip
      rescue
        nil
      end

      def has_search_input?
        page.locator("input[placeholder='Ask a question...']").first.visible?
      rescue
        false
      end

      def has_section_card?(name)
        page.locator("h3:has-text('#{name}')").count > 0
      rescue
        false
      end

      def section_card_count
        # Section cards are inside "Browse by category" grid, each card has an h3
        page.locator("h2:has-text('Browse by category') ~ div h3").count
      rescue
        0
      end

      def has_article_card?(title)
        page.locator("h3:has-text('#{title}')").count > 0
      rescue
        false
      end

      def has_browse_by_category?
        page.locator("h2:has-text('Browse by category')").visible?
      rescue
        false
      end

      def has_popular_articles?
        page.locator("h2:has-text('Popular articles')").visible?
      rescue
        false
      end

      def has_empty_state?
        page.locator("text=No articles published yet.").visible?
      rescue
        false
      end

      def section_card_article_count_text(name)
        # Each section card shows article count as "N articles" in a p.text-xs.text-muted
        card = page.locator(".bg-card:has(h3:has-text('#{name}'))")
        card.locator("p.text-xs").text_content.strip
      rescue
        nil
      end

      # =====================
      # Section Page
      # =====================

      def section_heading
        # Target the main content h1, not the header h1
        page.locator("h1.text-2xl").text_content.strip
      rescue
        nil
      end

      def has_breadcrumb?
        page.locator("nav.text-sm").visible?
      rescue
        false
      end

      def breadcrumb_text
        page.locator("nav.text-sm").text_content.strip
      rescue
        nil
      end

      def article_card_count
        # Article cards on the section page are inside the grid
        page.locator(".grid a.block").count
      rescue
        0
      end

      def has_section_empty_state?
        page.locator("text=No articles in this section yet.").visible?
      rescue
        false
      end

      # =====================
      # Article Page
      # =====================

      def article_title
        # Target the main content h1, not the header h1
        page.locator("h1.text-2xl").text_content.strip
      rescue
        nil
      end

      def has_introduction?
        # Introduction is a p.text-lg inside the article content
        page.locator("p.text-lg.text-body").count > 0
      rescue
        false
      end

      def has_prerequisites?
        page.locator("#prerequisites").visible?
      rescue
        false
      end

      def has_steps?
        page.locator("#steps").visible?
      rescue
        false
      end

      def has_tips?
        page.locator("#tips").visible?
      rescue
        false
      end

      def has_summary?
        page.locator("#summary").visible?
      rescue
        false
      end

      def has_table_of_contents?
        page.locator("h3:has-text('On this page')").count > 0
      rescue
        false
      end

      def has_feedback_widget?
        page.locator("text=Was this article helpful?").visible?
      rescue
        false
      end

      def click_feedback_helpful
        page.locator("button:has-text('Yes, helpful')").click
        sleep 0.3 # Wait for Stimulus controller to process
      end

      def feedback_thankyou_visible?
        page.locator("text=Thank you for your feedback!").visible?
      rescue
        false
      end

      def has_support_contact?
        page.locator("h3:has-text('Still need help?')").visible?
      rescue
        false
      end

      def has_related_articles?
        page.locator("h3:has-text('Related articles')").visible?
      rescue
        false
      end

      def click_breadcrumb_help_centre
        page.locator("nav.text-sm a:has-text('Help Centre')").click
        wait_for_turbo
      end

      def click_section_card(name)
        page.locator("h3:has-text('#{name}')").first.click
        wait_for_turbo
      end

      def click_article_link(title)
        page.locator("a:has-text('#{title}')").first.click
        wait_for_turbo
      end
    end
  end
end

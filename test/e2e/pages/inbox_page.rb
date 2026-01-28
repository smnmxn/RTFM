require_relative "base_page"

module E2E
  module Pages
    class InboxPage < BasePage
      # Visit the project dashboard (defaults to Inbox tab)
      def visit_project(project_slug)
        page.goto("#{test_case.send(:app_url)}/projects/#{project_slug}")
        wait_for_turbo
        self
      end

      # =====================
      # Tab Navigation
      # =====================

      def click_inbox_tab
        click("button[data-tabs-name='inbox']")
        wait_for_turbo
      end

      def on_inbox_tab?
        has_element?("button[data-tabs-name='inbox'].border-indigo-500")
      end

      # =====================
      # Article List
      # =====================

      def has_articles_section?
        # Check if the articles section exists and contains article items
        section = page.locator("#articles-section")
        return false unless section.count > 0

        # Check if section has visible content (articles list or header)
        section.visible? && page.locator("#articles-list").count > 0
      rescue
        false
      end

      def articles_section_visible?
        has_articles_section?
      end

      def article_count
        page.locator("#articles-list > div").count
      rescue
        0
      end

      def has_article?(title)
        # Check if an article with this title exists in the articles list
        page.locator("#articles-list").count > 0 &&
          page.locator("#articles-list p.text-sm.font-medium:has-text('#{title}')").count > 0
      rescue
        false
      end

      def first_article_title
        page.locator("#articles-list p.text-sm.font-medium").first.text_content
      rescue
        nil
      end

      def select_article(title)
        click("#articles-list a:has-text('#{title}')")
        wait_for_turbo
      end

      def article_selected?(title)
        # Selected article has indigo border and background
        page.locator("#articles-list a:has-text('#{title}')").evaluate("el => el.classList.contains('border-indigo-500')")
      rescue
        false
      end

      def article_has_spinner?(title)
        # Look for the article row and check if it has an animated spinner
        row = page.locator("[id^='article_'][id$='_row']:has-text('#{title}')")
        row.locator("svg.animate-spin, .animate-spin").count > 0
      rescue
        false
      end

      # =====================
      # Recommendation List
      # =====================

      def has_recommendations_section?
        # Check if the suggestions section exists and contains recommendation items
        section = page.locator("#recommendations-section")
        return false unless section.count > 0

        # Check if section has visible content
        section.visible? && page.locator("#recommendations-list").count > 0
      rescue
        false
      end

      def recommendations_section_visible?
        has_recommendations_section?
      end

      def recommendation_count
        page.locator("#recommendations-list > div").count
      rescue
        0
      end

      def has_recommendation?(title)
        # Check if a recommendation with this title exists in the list
        page.locator("#recommendations-list").count > 0 &&
          page.locator("#recommendations-list p.text-sm.font-medium:has-text('#{title}')").count > 0
      rescue
        false
      end

      def first_recommendation_title
        page.locator("#recommendations-list p.text-sm.font-medium").first.text_content
      rescue
        nil
      end

      def select_recommendation(title)
        click("#recommendations-list a:has-text('#{title}')")
        wait_for_turbo
      end

      def recommendation_selected?(title)
        page.locator("#recommendations-list a:has-text('#{title}')").evaluate("el => el.classList.contains('border-indigo-500')")
      rescue
        false
      end

      # =====================
      # Editor Panel
      # =====================

      def editor_shows_article?(title)
        frame = page.locator("turbo-frame#inbox-editor")
        frame.visible? && frame.locator("h1, h2, h3, input").first.input_value == title rescue frame.text_content.include?(title)
      rescue
        false
      end

      def editor_shows_title?(title)
        # The title is rendered as an editable input or text
        page.locator("turbo-frame#inbox-editor").text_content.include?(title)
      rescue
        false
      end

      def editor_shows_recommendation?(title)
        frame = page.locator("turbo-frame#inbox-editor")
        frame.visible? && frame.text_content.include?(title) && frame.text_content.include?("Why this article?")
      rescue
        false
      end

      def editor_shows_description?(description)
        page.locator("turbo-frame#inbox-editor").text_content.include?(description)
      rescue
        false
      end

      def editor_shows_generating_state?
        frame = page.locator("turbo-frame#inbox-editor")
        frame.text_content.include?("Generating...") || frame.text_content.include?("being generated")
      rescue
        false
      end

      def editor_shows_failed_state?
        frame = page.locator("turbo-frame#inbox-editor")
        frame.text_content.include?("generation failed")
      rescue
        false
      end

      def editor_shows_approved_state?
        page.locator("turbo-frame#inbox-editor").text_content.include?("Approved")
      rescue
        false
      end

      def editor_shows_rejected_state?
        frame = page.locator("turbo-frame#inbox-editor")
        frame.text_content.include?("Rejected") || frame.locator("text=Rejected").count > 0
      rescue
        false
      end

      # =====================
      # Action Buttons
      # =====================

      def has_approve_button?
        # Approve button can be either a button element or within a section picker modal
        page.locator("turbo-frame#inbox-editor button:has-text('Approve')").count > 0 ||
          page.locator("turbo-frame#inbox-editor input[value='Approve']").count > 0
      rescue
        false
      end

      def has_reject_button?
        page.locator("turbo-frame#inbox-editor button:has-text('Reject')").visible?
      rescue
        false
      end

      def has_accept_button?
        page.locator("turbo-frame#inbox-editor button:has-text('Accept')").visible?
      rescue
        false
      end

      def has_undo_button?
        page.locator("turbo-frame#inbox-editor button:has-text('Undo')").visible?
      rescue
        false
      end

      def has_regenerate_button?
        page.locator("turbo-frame#inbox-editor button:has-text('Regenerate')").visible?
      rescue
        false
      end

      def has_preview_button?
        page.locator("turbo-frame#inbox-editor button:has-text('Preview'), turbo-frame#inbox-editor a:has-text('Preview')").visible?
      rescue
        false
      end

      # =====================
      # Article Actions
      # =====================

      def approve_article
        click("turbo-frame#inbox-editor button:has-text('Approve')")
        wait_for_turbo
        sleep 0.5  # Wait for turbo stream updates
      end

      def approve_article_with_section(section_name)
        # Click Approve to open section picker modal
        click("turbo-frame#inbox-editor button:has-text('Approve')")
        wait_for_turbo
        sleep 0.3  # Wait for modal animation

        # Select section from dropdown
        page.select_option("select[name='section_id']", label: section_name)

        # Submit the form
        click("input[value='Approve']")
        wait_for_turbo
        sleep 0.5  # Wait for turbo stream updates
      end

      def reject_article
        click("turbo-frame#inbox-editor button:has-text('Reject')")
        wait_for_turbo
      end

      def undo_reject
        click("turbo-frame#inbox-editor button:has-text('Undo')")
        wait_for_turbo
      end

      # =====================
      # Recommendation Actions
      # =====================

      def accept_recommendation
        click("turbo-frame#inbox-editor button:has-text('Accept')")
        wait_for_turbo
        # Wait a bit more for the turbo stream update to complete
        sleep 0.5
      end

      def reject_recommendation
        click("turbo-frame#inbox-editor button:has-text('Reject')")
        wait_for_turbo
        # Wait a bit more for turbo stream updates
        sleep 0.5
      end

      # =====================
      # Section Picker Modal
      # =====================

      def section_picker_visible?
        has_text?("Choose a Section")
      end

      def select_section_in_picker(section_name)
        page.select_option("select[name='section_id']", label: section_name)
      end

      def submit_section_picker
        click("input[value='Approve']")
        wait_for_turbo
      end

      def cancel_section_picker
        click("button:has-text('Cancel')")
        wait_for_turbo
      end

      # =====================
      # Empty State
      # =====================

      def has_empty_state?
        has_element?("#inbox-empty-state") && has_text?("All done!")
      end

      def empty_state_visible?
        element = page.locator("#inbox-empty-state")
        !element.evaluate("el => el.classList.contains('hidden')") && element.visible?
      rescue
        false
      end

      def has_help_centre_link?
        has_text?("View Help Centre")
      end

      # =====================
      # Progress Indicator
      # =====================

      def has_progress_indicator?
        has_element?("#inbox-progress")
      end

      def progress_text
        page.locator("#inbox-progress span").first.text_content
      rescue
        ""
      end

      def progress_shows_pending?(count)
        progress_text.include?("#{count} pending")
      end

      def progress_shows_approved_ratio?(approved, total)
        progress_text.include?("#{approved}/#{total} approved")
      end

      # =====================
      # URL & Navigation
      # =====================

      def url_contains_selected?(type, id)
        page.url.include?("selected=#{type}_#{id}")
      end

      def current_selected_param
        uri = URI.parse(page.url)
        params = URI.decode_www_form(uri.query || "").to_h
        params["selected"]
      rescue
        nil
      end
    end
  end
end

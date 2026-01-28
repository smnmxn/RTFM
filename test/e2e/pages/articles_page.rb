require_relative "base_page"

module E2E
  module Pages
    class ArticlesPage < BasePage
      # Visit the project dashboard and navigate to Articles tab
      def visit_project(project_slug)
        page.goto("#{test_case.send(:app_url)}/projects/#{project_slug}")
        wait_for_turbo
        self
      end

      # =====================
      # Tab Navigation
      # =====================

      def click_articles_tab
        click("button[data-tabs-name='articles']")
        wait_for_turbo
        sleep 0.5 # Wait for panel to show and articles to load
      end

      def on_articles_tab?
        has_element?("button[data-tabs-name='articles'].border-indigo-500")
      end

      def click_inbox_tab
        click("button[data-tabs-name='inbox']")
        wait_for_turbo
      end

      # =====================
      # Folder Tree (Left Panel)
      # =====================

      def section_count
        page.locator("[id^='folder-section-']").count
      rescue
        0
      end

      def has_section?(name)
        page.locator("#articles-folder-tree span.font-medium:has-text('#{name}')").count > 0
      rescue
        false
      end

      def select_section(name)
        click("#articles-folder-tree button:has-text('#{name}')")
        wait_for_turbo
      end

      def expand_section(name)
        # Click the section header to expand if collapsed
        section = page.locator("[id^='folder-section-']:has-text('#{name}')")
        chevron = section.locator("[data-folder-section-target='chevron']")
        # Check if collapsed (no rotate-90 class means collapsed)
        unless chevron.evaluate("el => el.classList.contains('rotate-90')")
          section.locator("button[data-action*='folder-section#toggle']").click
          sleep 0.2
        end
      end

      def collapse_section(name)
        section = page.locator("[id^='folder-section-']:has-text('#{name}')")
        chevron = section.locator("[data-folder-section-target='chevron']")
        # Check if expanded (has rotate-90 class)
        if chevron.evaluate("el => el.classList.contains('rotate-90')")
          section.locator("button[data-action*='folder-section#toggle']").click
          sleep 0.2
        end
      end

      def section_expanded?(name)
        section = page.locator("[id^='folder-section-']:has-text('#{name}')")
        content = section.locator("[data-folder-section-target='content']")
        !content.evaluate("el => el.classList.contains('hidden')")
      rescue
        false
      end

      def section_article_count(name)
        # The count is shown in parentheses next to the section name
        section = page.locator("[id^='folder-section-']:has-text('#{name}')")
        count_text = section.locator("span.text-xs.text-gray-400").first.text_content
        count_text.gsub(/[()]/, "").to_i
      rescue
        0
      end

      def article_count_in_tree
        page.locator("[id^='folder_article_']").count
      rescue
        0
      end

      def has_article_in_tree?(title)
        page.locator("#articles-folder-tree [id^='folder_article_']:has-text('#{title}')").count > 0
      rescue
        false
      end

      def select_article(title)
        click("#articles-folder-tree a:has-text('#{title}')")
        wait_for_turbo
        sleep 0.3 # Wait for editor to load
      end

      def article_selected?(title)
        page.locator("#articles-folder-tree [id^='folder_article_']:has-text('#{title}')").evaluate("el => el.classList.contains('border-indigo-500')")
      rescue
        false
      end

      def article_published_in_tree?(title)
        # Published articles have regular text, draft articles have text-gray-400 and italic
        article = page.locator("#articles-folder-tree [id^='folder_article_']:has-text('#{title}') span.text-sm")
        !article.evaluate("el => el.classList.contains('text-gray-400')")
      rescue
        false
      end

      # =====================
      # Editor Panel (Right Panel)
      # =====================

      def editor_visible?
        has_element?("turbo-frame#articles-editor-frame")
      end

      def editor_shows_article?(title)
        frame = page.locator("turbo-frame#articles-editor-frame")
        frame.visible? && frame.text_content.include?(title)
      rescue
        false
      end

      def editor_shows_empty_state?
        frame = page.locator("turbo-frame#articles-editor-frame")
        frame.text_content.include?("No articles yet") || frame.text_content.include?("Create your first article")
      rescue
        false
      end

      def editor_article_title
        page.locator("turbo-frame#articles-editor-frame input[data-inline-edit-target='input']").first.input_value
      rescue
        page.locator("turbo-frame#articles-editor-frame h1, turbo-frame#articles-editor-frame .text-xl").first.text_content
      rescue
        nil
      end

      def editor_article_status
        frame = page.locator("turbo-frame#articles-editor-frame")
        if frame.locator("span:has-text('Published')").count > 0
          "Published"
        else
          "Draft"
        end
      rescue
        nil
      end

      def editor_shows_generating_state?
        frame = page.locator("turbo-frame#articles-editor-frame")
        frame.text_content.include?("Generating...") || frame.text_content.include?("being generated")
      rescue
        false
      end

      def editor_shows_failed_state?
        frame = page.locator("turbo-frame#articles-editor-frame")
        frame.text_content.include?("generation failed")
      rescue
        false
      end

      def editor_shows_ready_to_generate?
        frame = page.locator("turbo-frame#articles-editor-frame")
        frame.text_content.include?("Ready to generate")
      rescue
        false
      end

      # =====================
      # Action Buttons
      # =====================

      def has_publish_button?
        # Check for Publish button that is NOT Unpublish
        frame = page.locator("turbo-frame#articles-editor-frame")
        # Look for buttons and check their text
        buttons = frame.locator("button")
        buttons.all.any? do |btn|
          text = btn.text_content.strip
          text.include?("Publish") && !text.include?("Unpublish")
        end
      rescue
        false
      end

      def has_unpublish_button?
        frame = page.locator("turbo-frame#articles-editor-frame")
        buttons = frame.locator("button")
        buttons.all.any? do |btn|
          btn.text_content.strip.include?("Unpublish")
        end
      rescue
        false
      end

      def has_generate_button?
        # The Generate button is inside a regenerate-modal controller div
        page.locator("turbo-frame#articles-editor-frame [data-controller='regenerate-modal'] button:has-text('Generate')").count > 0
      rescue
        false
      end

      def has_regenerate_button?
        # The Regenerate button is inside a regenerate-modal controller div
        page.locator("turbo-frame#articles-editor-frame [data-controller='regenerate-modal'] button:has-text('Regenerate')").count > 0
      rescue
        false
      end

      def has_delete_button?
        page.locator("turbo-frame#articles-editor-frame button[title='Delete']").visible?
      rescue
        false
      end

      def has_duplicate_button?
        page.locator("turbo-frame#articles-editor-frame button[title='Duplicate']").visible?
      rescue
        false
      end

      def has_preview_button?
        page.locator("turbo-frame#articles-editor-frame [data-controller='article-preview'] button:has-text('Preview')").count > 0
      rescue
        false
      end

      # =====================
      # Article Actions
      # =====================

      def publish_article
        click("turbo-frame#articles-editor-frame button:has-text('Publish')")
        wait_for_turbo
        sleep 0.5
      end

      def unpublish_article
        click("turbo-frame#articles-editor-frame button:has-text('Unpublish')")
        wait_for_turbo
        sleep 0.5
      end

      def delete_article
        # This will trigger a confirmation dialog
        page.locator("turbo-frame#articles-editor-frame button[title='Delete']").click
        # Accept the confirmation
        page.on("dialog", ->(dialog) { dialog.accept })
        wait_for_turbo
        sleep 0.5
      end

      def delete_article_with_confirmation
        page.locator("turbo-frame#articles-editor-frame button[title='Delete']").click
        sleep 0.2
        # The confirmation is handled by Turbo confirm
        wait_for_turbo
        sleep 0.5
      end

      def duplicate_article
        click("turbo-frame#articles-editor-frame button[title='Duplicate']")
        wait_for_turbo
        sleep 1.0 # Wait for turbo stream to update folder tree
      end

      def click_preview
        click("turbo-frame#articles-editor-frame label:has-text('Preview')")
        wait_for_turbo
        sleep 0.3
      end

      # =====================
      # Create Article Modal
      # =====================

      def open_new_article_modal
        click("button:has-text('New Article')")
        sleep 0.3 # Wait for modal animation
      end

      def new_article_modal_visible?
        page.locator("[data-new-article-modal-target='dialog']:not(.hidden)").visible?
      rescue
        false
      end

      def fill_article_title(title)
        page.fill("#new-article-title", title)
      end

      def fill_article_description(description)
        page.fill("#new-article-description", description)
      end

      def select_article_section(section_name)
        page.select_option("#new-article-section", label: section_name)
      end

      def submit_new_article
        click("button:has-text('Create Article')")
        # Wait for the modal to close and page to navigate/update
        page.wait_for_load_state(state: "networkidle")
        wait_for_turbo
        sleep 1.0 # Extra wait for turbo updates
      end

      def close_new_article_modal
        page.locator("[data-new-article-modal-target='dialog'] button:has-text('Cancel')").click
        sleep 0.3
      end

      # =====================
      # Section Management
      # =====================

      def open_new_section_modal
        # Click the plus button next to "Sections & Articles" header
        click("[data-controller='section-modal'] button[data-action='section-modal#open']")
        sleep 0.3
      end

      def new_section_modal_visible?
        page.locator("[data-section-modal-target='dialog']:not(.hidden)").visible?
      rescue
        false
      end

      def fill_section_name(name)
        page.fill("#new-section-name", name)
      end

      def fill_section_description(description)
        page.fill("#new-section-description", description)
      end

      def submit_new_section
        click("[data-section-modal-target='dialog'] button:has-text('Create Section')")
        wait_for_turbo
        sleep 0.5
      end

      def close_new_section_modal
        page.locator("[data-section-modal-target='dialog'] button:has-text('Cancel')").click
        sleep 0.3
      end

      def open_section_menu(section_name)
        section = page.locator("[id^='folder-section-']:has-text('#{section_name}')")
        section.hover
        section.locator("button[data-action='section-menu#toggle']").click
        sleep 0.2
      end

      def section_menu_visible?(section_name)
        section = page.locator("[id^='folder-section-']:has-text('#{section_name}')")
        section.locator("[data-section-menu-target='menu']:not(.hidden)").visible?
      rescue
        false
      end

      def click_edit_section(section_name)
        section = page.locator("[id^='folder-section-']:has-text('#{section_name}')")
        section.locator("button:has-text('Edit')").click
        sleep 0.3
      end

      def click_delete_section(section_name)
        section = page.locator("[id^='folder-section-']:has-text('#{section_name}')")
        section.locator("button:has-text('Delete')").click
        wait_for_turbo
        sleep 0.5
      end

      # =====================
      # Structured Content Editing
      # =====================

      def has_introduction_section?
        page.locator("turbo-frame#articles-editor-frame [id$='_introduction']").count > 0
      rescue
        false
      end

      def introduction_text
        page.locator("turbo-frame#articles-editor-frame [id$='_introduction'] p[data-inline-edit-target='display']").first.text_content
      rescue
        nil
      end

      def click_introduction_to_edit
        page.locator("turbo-frame#articles-editor-frame [id$='_introduction'] p[data-inline-edit-target='display']").first.click
        sleep 0.2
      end

      def fill_introduction(text)
        page.locator("turbo-frame#articles-editor-frame [id$='_introduction'] textarea[data-inline-edit-target='input']").fill(text)
      end

      def save_introduction
        # Press Enter or blur to save
        page.locator("turbo-frame#articles-editor-frame [id$='_introduction'] textarea[data-inline-edit-target='input']").press("Enter")
        wait_for_turbo
        sleep 0.3
      end

      def has_prerequisites_section?
        page.locator("turbo-frame#articles-editor-frame h3:has-text('Prerequisites')").count > 0
      rescue
        false
      end

      def prerequisites_count
        page.locator("turbo-frame#articles-editor-frame [id$='_prerequisites'] ul[data-array-edit-target='list'] li").count
      rescue
        0
      end

      def click_add_prerequisite
        click("turbo-frame#articles-editor-frame button:has-text('Add prerequisite')")
        wait_for_turbo
        sleep 0.3
      end

      def has_steps_section?
        page.locator("turbo-frame#articles-editor-frame h3:has-text('Steps')").count > 0
      rescue
        false
      end

      def steps_count
        # Count step number badges (the numbered circles)
        page.locator("turbo-frame#articles-editor-frame [id$='_steps'] span.bg-indigo-600.rounded-full").count
      rescue
        0
      end

      def click_add_step
        click("turbo-frame#articles-editor-frame button:has-text('Add step')")
        wait_for_turbo
        sleep 0.3
      end

      def has_tips_section?
        page.locator("turbo-frame#articles-editor-frame h3:has-text('Tips')").count > 0
      rescue
        false
      end

      def tips_count
        page.locator("turbo-frame#articles-editor-frame [id$='_tips'] ul[data-array-edit-target='list'] li").count
      rescue
        0
      end

      def click_add_tip
        click("turbo-frame#articles-editor-frame button:has-text('Add tip')")
        wait_for_turbo
        sleep 0.3
      end

      def has_summary_section?
        page.locator("turbo-frame#articles-editor-frame [id$='_summary']").count > 0
      rescue
        false
      end

      def summary_text
        page.locator("turbo-frame#articles-editor-frame [id$='_summary'] p[data-inline-edit-target='display']").first.text_content
      rescue
        nil
      end

      # =====================
      # URL & Navigation
      # =====================

      def url_contains_article_param?(article_id)
        page.url.include?("article=#{article_id}")
      end

      def current_url
        page.url
      end

      # =====================
      # Help Centre (Public Site)
      # =====================

      def visit_help_centre(project_slug)
        page.goto("#{test_case.send(:app_url)}/test/help_centre/#{project_slug}")
        wait_for_turbo
        self
      end

      def visit_help_centre_section(project_slug, section_slug)
        page.goto("#{test_case.send(:app_url)}/test/help_centre/#{project_slug}/#{section_slug}")
        wait_for_turbo
        self
      end

      def visit_help_centre_article(project_slug, section_slug, article_slug)
        page.goto("#{test_case.send(:app_url)}/test/help_centre/#{project_slug}/#{section_slug}/#{article_slug}")
        wait_for_turbo
        self
      end

      def help_centre_has_article?(title)
        page.locator("a:has-text('#{title}'), h1:has-text('#{title}')").count > 0
      rescue
        false
      end

      def help_centre_article_visible?(title)
        page.locator("text=#{title}").visible?
      rescue
        false
      end

      def help_centre_shows_404?
        page.locator("text=not found").count > 0 ||
          page.url.include?("404") ||
          page.locator("text=doesn't exist").count > 0
      rescue
        false
      end
    end
  end
end

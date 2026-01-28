require_relative "base_page"

module E2E
  module Pages
    class DashboardPage < BasePage
      def visit(project_slug)
        page.goto("#{test_case.send(:app_url)}/projects/#{project_slug}")
        wait_for_turbo
        self
      end

      def visit_projects_list
        page.goto("#{test_case.send(:app_url)}/projects")
        wait_for_turbo
        self
      end

      # Tab navigation
      def click_inbox_tab
        click("[data-tab='inbox']")
        wait_for_turbo
      end

      def click_articles_tab
        click("[data-tab='articles']")
        wait_for_turbo
      end

      def click_code_history_tab
        click("[data-tab='code-history']")
        wait_for_turbo
      end

      def click_settings_tab
        click("[data-tab='settings']")
        wait_for_turbo
      end

      # Project list actions
      def has_project?(name)
        has_text?(name)
      end

      def select_project(name)
        click("a:has-text('#{name}')")
        wait_for_turbo
      end

      def create_new_project
        click("a:has-text('New project')")
        wait_for_turbo
      end

      # Inbox actions
      def has_pending_articles?
        has_element?("[data-testid='pending-articles']")
      end

      def has_pending_recommendations?
        has_element?("[data-testid='pending-recommendations']")
      end

      def approve_first_article
        click("[data-action='approve-article']:first-of-type")
        wait_for_turbo
      end

      def reject_first_article
        click("[data-action='reject-article']:first-of-type")
        wait_for_turbo
      end

      # Settings actions
      def update_branding(title:, tagline: nil)
        fill("input[name='project[title]']", title) if title
        fill("input[name='project[tagline]']", tagline) if tagline
        click("button:has-text('Save')")
        wait_for_turbo
      end

      # State checks
      def on_projects_list?
        current_path == "/projects"
      end

      def on_project_dashboard?
        current_path.match?(%r{/projects/[^/]+$})
      end
    end
  end
end

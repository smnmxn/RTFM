require_relative "base_page"

module E2E
  module Pages
    class OnboardingPage < BasePage
      def visit_new
        page.goto("#{test_case.send(:base_url)}/onboarding/projects/new")
        wait_for_turbo
        self
      end

      def visit_step(project_slug, step)
        page.goto("#{test_case.send(:base_url)}/onboarding/projects/#{project_slug}/#{step}")
        page.wait_for_load_state(state: "networkidle")
        wait_for_turbo
        self
      end

      # Step 0: Landing/New
      def start_onboarding
        click("button:has-text('Get started')")
        wait_for_turbo
      end

      def has_landing_page?
        has_text?("Create your help centre") || has_text?("Get started")
      end

      # Step 1: Repository selection
      def on_repository_step?
        current_path.include?("/repository")
      end

      def wait_for_repositories
        page.wait_for_selector("[data-turbo-frame='repository_list']", timeout: 10_000)
        wait_for_turbo
      end

      def select_repository(repo_name)
        click("[data-repo='#{repo_name}']")
      end

      def has_repository?(repo_name)
        has_text?(repo_name)
      end

      # Step 2: Setup
      def on_setup_step?
        current_path.include?("/setup")
      end

      def fill_project_name(name)
        fill("input[name='project[name]']", name)
      end

      def fill_subdomain(subdomain)
        fill("input[name='project[subdomain]']", subdomain)
      end

      def select_branch(branch_name)
        # Handle branch selection dropdown or checkbox
        if has_element?("select[name*='branch']")
          page.select_option("select[name*='branch']", branch_name)
        else
          click("label:has-text('#{branch_name}')")
        end
      end

      # Step 3: Analyze
      def on_analyze_step?
        current_path.include?("/analyze")
      end

      def analysis_in_progress?
        has_text?("Analyzing") || has_element?("[data-analysis-status='in_progress']")
      end

      def analysis_completed?
        has_text?("Analysis complete") || has_element?("[data-analysis-status='completed']")
      end

      def fill_context(audience: nil, industry: nil, tone: nil)
        fill("textarea[name*='audience']", audience) if audience
        fill("input[name*='industry']", industry) if industry
        select_option("select[name*='tone']", tone) if tone && has_element?("select[name*='tone']")
      end

      # Step 4: Sections
      def on_sections_step?
        current_path.include?("/sections")
      end

      def accept_section(section_name)
        section = page.locator("text=#{section_name}").locator("xpath=ancestor::*[contains(@class, 'section')]")
        section.locator("button:has-text('Accept')").click
        wait_for_turbo
      end

      def reject_section(section_name)
        section = page.locator("text=#{section_name}").locator("xpath=ancestor::*[contains(@class, 'section')]")
        section.locator("button:has-text('Reject')").click
        wait_for_turbo
      end

      def complete_sections
        click("button:has-text('Continue')")
        wait_for_turbo
      end

      # Step 5: Generating
      def on_generating_step?
        current_path.include?("/generating")
      end

      def generation_in_progress?
        has_text?("Generating") || has_element?("[data-status='generating']")
      end

      def generation_completed?
        has_text?("Complete") || !current_path.include?("/generating")
      end

      # Common actions
      def click_continue
        click("button:has-text('Continue')")
        wait_for_turbo
      end

      def click_back
        click("button:has-text('Back')")
        wait_for_turbo
      end

      def current_step
        return :new if current_path.include?("/new")
        return :repository if current_path.include?("/repository")
        return :setup if current_path.include?("/setup")
        return :analyze if current_path.include?("/analyze")
        return :sections if current_path.include?("/sections")
        return :generating if current_path.include?("/generating")
        :unknown
      end

      # Error and retry helpers
      def has_error_state?
        has_text?("failed") || has_text?("error") || has_text?("Error")
      end

      def has_retry_button?
        has_element?("a:has-text('Retry')") || has_element?("input[value='Retry']") || has_element?("button:has-text('Retry')")
      end

      # Sections helpers
      def pending_section_count
        page.locator("#pending-sections-list [id^='section_']").count
      rescue
        0
      end

      def has_section_card?(name)
        has_text?(name)
      end

      def has_all_reviewed_message?
        has_text?("All topics reviewed")
      end

      # Generating helpers
      def has_progress_ui?
        has_text?("Creating your help centre") || has_text?("Generating") || has_element?(".animate-pulse")
      end

      private

      def select_option(selector, value)
        page.select_option(selector, value)
      end
    end
  end
end

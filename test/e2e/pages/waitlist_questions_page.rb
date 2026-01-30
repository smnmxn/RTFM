require_relative "base_page"

module E2E
  module Pages
    class WaitlistQuestionsPage < BasePage
      def on_questions_page?
        page.url.include?("/waitlist/questions/")
      end

      def has_question?(text)
        has_text?(text)
      end

      def select_option(label)
        click("label:has-text('#{label}')")
        # Wait for the radio to be checked and button to be enabled
        sleep 0.1
      end

      def click_next
        # Wait for button to be enabled
        page.wait_for_selector("button:has-text('Next'):not([disabled])", timeout: 5000)
        click("button:has-text('Next')")
        wait_for_turbo
        # Wait for card animation
        sleep 0.3
      end

      def click_skip
        click("button:has-text('Skip')")
        wait_for_turbo
      end

      def complete_all_questions
        # Question 1: Platform type
        select_option("Web application / SaaS")
        click_next

        # Question 2: Repo structure
        select_option("Single repository")
        click_next

        # Question 3: VCS provider
        select_option("GitHub")
        click_next

        # Question 4: Workflow
        select_option("Pull requests")
        click_next

        # Question 5: User base (last one shows "Done" button)
        select_option("100-1,000 users")
        page.wait_for_selector("button:has-text('Done'):not([disabled])", timeout: 5000)
        click("button:has-text('Done')")
        wait_for_turbo

        # Wait for completion message and redirect
        page.wait_for_load_state(state: "networkidle")
      end

      def skip_all_questions
        5.times do
          click_skip
          sleep 0.3 # Wait for animation
        end
        page.wait_for_load_state(state: "networkidle")
      end

      def has_completion_message?
        has_text?("You're on the list!")
      end
    end
  end
end

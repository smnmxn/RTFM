module E2E
  module Pages
    class BasePage
      attr_reader :page, :test_case

      def initialize(page, test_case)
        @page = page
        @test_case = test_case
      end

      def wait_for_turbo
        page.wait_for_function(<<~JS)
          () => {
            if (document.body.classList.contains('turbo-loading')) return false;
            const frames = document.querySelectorAll('turbo-frame[busy]');
            return frames.length === 0;
          }
        JS
      rescue Playwright::TimeoutError
        # Turbo may have already completed
      end

      def current_url
        page.url
      end

      def current_path
        URI.parse(page.url).path
      end

      def has_text?(text)
        page.locator("text=#{text}").visible?
      rescue
        false
      end

      def has_element?(selector)
        page.locator(selector).visible?
      rescue
        false
      end

      def click(selector)
        page.click(selector)
      end

      def fill(selector, value)
        page.fill(selector, value)
      end

      def screenshot(name)
        path = Rails.root.join("tmp/screenshots/#{name}.png")
        FileUtils.mkdir_p(File.dirname(path))
        page.screenshot(path: path.to_s)
      end
    end
  end
end

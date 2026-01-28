module E2E
  module WaitHelpers
    # Wait for Turbo to finish any navigation or frame updates
    def wait_for_turbo(timeout: 10_000)
      @page.wait_for_function(<<~JS, timeout: timeout)
        () => {
          // Wait for Turbo Drive navigation to complete
          if (document.body.classList.contains('turbo-loading')) return false;

          // Wait for any pending Turbo frames
          const frames = document.querySelectorAll('turbo-frame[busy]');
          if (frames.length > 0) return false;

          return true;
        }
      JS
    rescue Playwright::TimeoutError
      # Turbo may have already completed
    end

    # Wait for a specific Turbo Frame to finish loading
    def wait_for_turbo_frame(frame_id, timeout: 10_000)
      @page.wait_for_selector("turbo-frame##{frame_id}:not([busy])", timeout: timeout)
    rescue Playwright::TimeoutError
      raise "Turbo frame ##{frame_id} did not finish loading within #{timeout}ms"
    end

    # Wait for Turbo Streams to be processed (streams are removed after processing)
    def wait_for_turbo_stream(timeout: 5_000)
      @page.wait_for_selector("turbo-stream", state: "detached", timeout: timeout)
    rescue Playwright::TimeoutError
      # Stream may have already been processed or none was sent
    end

    # Wait for an element to appear
    def wait_for_element(selector, timeout: 10_000)
      @page.wait_for_selector(selector, timeout: timeout)
    rescue Playwright::TimeoutError
      raise "Element '#{selector}' did not appear within #{timeout}ms"
    end

    # Wait for an element to disappear
    def wait_for_element_removed(selector, timeout: 10_000)
      @page.wait_for_selector(selector, state: "detached", timeout: timeout)
    rescue Playwright::TimeoutError
      raise "Element '#{selector}' did not disappear within #{timeout}ms"
    end

    # Wait for specific text to appear on the page
    def wait_for_text(text, timeout: 10_000)
      @page.wait_for_selector("text=#{text}", timeout: timeout)
    rescue Playwright::TimeoutError
      raise "Text '#{text}' did not appear within #{timeout}ms"
    end

    # Wait for page to reach a specific URL pattern
    def wait_for_url(pattern, timeout: 10_000)
      @page.wait_for_url(pattern, timeout: timeout)
    rescue Playwright::TimeoutError
      raise "URL did not match '#{pattern}' within #{timeout}ms (current: #{@page.url})"
    end

    # Wait for network to be idle (useful for AJAX-heavy pages)
    def wait_for_network_idle(timeout: 10_000)
      @page.wait_for_load_state("networkidle", timeout: timeout)
    rescue Playwright::TimeoutError
      # Network may never be fully idle if there are websockets
    end

    # Poll until a block returns true
    def wait_until(timeout: 10_000, interval: 100)
      deadline = Time.current + (timeout / 1000.0)
      while Time.current < deadline
        return if yield
        sleep(interval / 1000.0)
      end
      raise "Condition not met within #{timeout}ms"
    end
  end
end

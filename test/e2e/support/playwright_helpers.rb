module E2E
  module PlaywrightHelpers
    # Fill a form field and blur to trigger change events
    def fill_and_blur(selector, value)
      @page.fill(selector, value)
      @page.locator(selector).blur
    end

    # Select an option from a dropdown
    def select_option(selector, value)
      @page.select_option(selector, value)
    end

    # Check a checkbox
    def check(selector)
      @page.check(selector)
    end

    # Uncheck a checkbox
    def uncheck(selector)
      @page.uncheck(selector)
    end

    # Upload a file
    def attach_file(selector, file_path)
      @page.set_input_files(selector, file_path)
    end

    # Get text content of an element
    def text_of(selector)
      @page.locator(selector).text_content
    end

    # Get attribute value of an element
    def attribute_of(selector, attribute)
      @page.locator(selector).get_attribute(attribute)
    end

    # Check if element is visible
    def visible?(selector)
      @page.locator(selector).visible?
    rescue
      false
    end

    # Check if element exists in DOM (even if hidden)
    def exists?(selector)
      @page.locator(selector).count > 0
    end

    # Get count of matching elements
    def count_of(selector)
      @page.locator(selector).count
    end

    # Hover over an element
    def hover(selector)
      @page.hover(selector)
    end

    # Double click an element
    def double_click(selector)
      @page.dblclick(selector)
    end

    # Press a keyboard key
    def press(key)
      @page.keyboard.press(key)
    end

    # Type text (character by character, useful for autocomplete)
    def type_text(text, delay: 100)
      @page.keyboard.type(text, delay: delay)
    end

    # Take a screenshot (useful for debugging)
    def screenshot(name = nil)
      name ||= "screenshot-#{Time.current.to_i}"
      path = Rails.root.join("tmp/screenshots/#{name}.png")
      FileUtils.mkdir_p(File.dirname(path))
      @page.screenshot(path: path.to_s)
      path
    end

    # Get console messages (useful for debugging JS errors)
    def console_messages
      @console_messages ||= []
    end

    # Enable console message capture
    def capture_console_messages
      @console_messages = []
      @page.on("console", ->(msg) { @console_messages << msg.text })
    end

    # Execute JavaScript in the page context
    def evaluate(script)
      @page.evaluate(script)
    end

    # Execute JavaScript and return result
    def evaluate_handle(script)
      @page.evaluate_handle(script)
    end
  end
end

require "test_helper"
require "playwright"
require "socket"

# Load E2E support files
Dir[Rails.root.join("test/e2e/support/**/*.rb")].each { |f| require f }

class E2ETestCase < ActionDispatch::IntegrationTest
  include E2E::AuthHelpers
  include E2E::WaitHelpers

  @@playwright = nil
  @@browser = nil
  @@server_thread = nil
  @@server_port = nil
  @@initialized = false

  setup do
    ensure_e2e_environment_started

    @context = @@browser.new_context
    @page = @context.new_page
    @page.set_default_timeout(10_000)
  end

  teardown do
    if @page
      # Screenshot on failure
      unless passed?
        FileUtils.mkdir_p(Rails.root.join("tmp/screenshots"))
        screenshot_path = Rails.root.join("tmp/screenshots/#{self.class.name}-#{name}.png")
        @page.screenshot(path: screenshot_path.to_s) rescue nil
      end
      @page.close rescue nil
    end
    @context&.close rescue nil
  end

  private

  def ensure_e2e_environment_started
    return if @@initialized

    @@server_port = find_available_port

    # Set BASE_DOMAIN for the server to use
    ENV["BASE_DOMAIN"] = "127.0.0.1:#{@@server_port}"

    # Start Rails server in a thread
    @@server_thread = Thread.new do
      ENV["RAILS_ENV"] = "test"
      require "rack/handler/puma"
      Rack::Handler::Puma.run(
        Rails.application,
        Port: @@server_port,
        Silent: true,
        Threads: "1:1"
      )
    end

    # Wait for server to start
    wait_for_server(@@server_port)

    # Start Playwright - the create method returns a Playwright instance
    playwright_path = find_playwright_path
    @@playwright = Playwright.create(playwright_cli_executable_path: playwright_path)
    @@browser = @@playwright.playwright.chromium.launch(
      headless: ENV["HEADLESS"] != "false",
      slowMo: ENV["SLOW_MO"]&.to_i || 0
    )

    @@initialized = true

    # Register cleanup at exit
    at_exit do
      @@browser&.close rescue nil
      @@playwright&.stop rescue nil
    end
  end

  def find_available_port
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    server.close
    port
  end

  def wait_for_server(port, timeout: 30)
    deadline = Time.current + timeout
    while Time.current < deadline
      begin
        TCPSocket.new("127.0.0.1", port).close
        return true
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
    end
    raise "Server didn't start within #{timeout} seconds"
  end

  def find_playwright_path
    # Check for npx
    if system("which npx > /dev/null 2>&1")
      "npx playwright"
    else
      "playwright"
    end
  end

  def base_url
    "http://127.0.0.1:#{@@server_port}"
  end

  def visit(path)
    full_url = path.start_with?("http") ? path : "#{base_url}#{path}"
    @page.goto(full_url)
  end

  def current_path
    URI.parse(@page.url).path
  end

  def assert_path(expected_path)
    assert_match(/#{Regexp.escape(expected_path)}/, @page.url, "Expected URL to include #{expected_path}")
  end

  def assert_text_visible(text)
    assert @page.locator("text=#{text}").visible?, "Expected '#{text}' to be visible on page"
  end

  def click_button(text)
    @page.click("button:has-text('#{text}')")
  end

  def click_link(text)
    @page.click("a:has-text('#{text}')")
  end

  def fill_in(selector, with:)
    @page.fill(selector, with)
  end

  def visible?(selector)
    @page.locator(selector).visible?
  rescue
    false
  end

  def has_text?(text)
    @page.locator("text=#{text}").visible?
  rescue
    false
  end
end

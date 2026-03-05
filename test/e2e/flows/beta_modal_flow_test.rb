require "e2e_test_helper"

class BetaModalFlowTest < E2ETestCase
  def setup
    super
    @user = users(:one)
  end

  test "beta modal displays after video completion" do
    visit "/"

    # Modal should not be visible initially
    refute modal_visible?

    # Trigger video completion
    trigger_video_completion

    # Modal should be visible
    assert modal_visible?, "Expected modal to be visible after video completion"
    assert has_text?("We're in private beta")
    assert has_text?("Join our waitlist for early access to SupportPages")
  end

  test "beta modal can be dismissed with X button" do
    visit "/"

    trigger_video_completion

    # Modal should be visible
    assert modal_visible?, "Expected modal to be visible"

    # Click X button
    click_button_selector("[data-action='beta-waitlist-modal#close']")
    wait_for_timeout(300)

    # Modal should be hidden
    refute modal_visible?, "Expected modal to be hidden after close button click"
  end

  test "beta modal can be dismissed with Escape key" do
    visit "/"

    trigger_video_completion

    # Modal should be visible
    assert modal_visible?, "Expected modal to be visible"

    # Press Escape key
    @page.keyboard.press("Escape")
    wait_for_timeout(300)

    # Modal should be hidden
    refute modal_visible?, "Expected modal to be hidden after Escape key"
  end

  test "beta modal submits email and redirects to questionnaire" do
    visit "/"

    trigger_video_completion

    # Wait for modal to be fully visible
    assert modal_visible?, "Expected modal to be visible"

    # Fill in email - wait for input to be visible
    @page.wait_for_selector("[data-beta-waitlist-modal-target='emailInput']:not(.hidden)", state: "visible")
    fill_in_selector("[data-beta-waitlist-modal-target='emailInput']", with: "test@example.com")

    # Submit form
    click_button "Join Waitlist"

    # Wait for navigation to complete
    @page.wait_for_url(/\/waitlist\/questions\//, timeout: 5000)

    # Should be on questionnaire page
    assert current_path.include?("/waitlist/questions/"), "Expected to be redirected to questionnaire page"

    # Verify database entry
    entry = WaitlistEntry.find_by(email: "test@example.com")
    assert_not_nil entry
    assert_nil entry.questions_completed_at, "Questions should not be completed yet"
  end

  test "beta modal only shows once per session" do
    visit "/"

    # First video completion
    trigger_video_completion

    # Modal should be visible
    assert modal_visible?, "Expected modal to be visible on first trigger"

    # Close modal
    click_button_selector("[data-action='beta-waitlist-modal#close']")
    wait_for_timeout(300)

    # Trigger video completion again by manually dispatching the event
    # (simulates video ending a second time without clicking poster again)
    @page.evaluate(<<~JS)
      () => {
        window.dispatchEvent(new CustomEvent('video-complete', {
          detail: { duration: 90 }
        }));
      }
    JS

    # Wait for potential modal delay
    wait_for_timeout(1500)

    # Modal should NOT appear again
    refute modal_visible?, "Expected modal to NOT be visible on second trigger"
  end

  test "beta modal validates email format before submission" do
    visit "/"

    trigger_video_completion

    # Wait for modal to be fully visible
    assert modal_visible?, "Expected modal to be visible"

    # Try invalid email
    @page.wait_for_selector("[data-beta-waitlist-modal-target='emailInput']:not(.hidden)", state: "visible")
    fill_in_selector("[data-beta-waitlist-modal-target='emailInput']", with: "invalid-email")
    click_button "Join Waitlist"

    wait_for_timeout(300)

    # Modal should still be visible (submission blocked)
    assert modal_visible?, "Expected modal to remain visible after invalid submission"
    refute has_text?("You're on the list!")
  end

  private

  def trigger_video_completion
    # Click play button to start video
    click_selector("[data-video-player-target='poster']")

    # Wait for video to actually start playing and analytics listeners to be set up
    wait_for_timeout(1000)

    # Fast-forward video to end and wait for ended event
    result = @page.evaluate(<<~JS)
      () => {
        return new Promise((resolve) => {
          const video = document.querySelector('video');
          if (!video) {
            resolve({ error: 'No video found' });
            return;
          }

          // Add our own ended listener to know when it fires
          video.addEventListener('ended', () => {
            resolve({ success: true, duration: video.duration });
          }, { once: true });

          // Fast forward to near the end
          video.currentTime = video.duration - 0.1;
        });
      }
    JS

    # Wait additional time for modal delay (1 second from when ended event fires)
    wait_for_timeout(1500)
  end

  def modal_visible?
    # Check if dialog target does not have 'hidden' class
    @page.evaluate(<<~JS)
      () => {
        const dialog = document.querySelector('[data-beta-waitlist-modal-target="dialog"]');
        if (!dialog) return false;
        return !dialog.classList.contains('hidden');
      }
    JS
  rescue
    false
  end

  def click_selector(selector)
    @page.click(selector)
  end

  def click_button_selector(selector)
    @page.click(selector)
  end

  def fill_in_selector(selector, with:)
    @page.fill(selector, with)
  end

  def has_selector?(selector)
    @page.query_selector(selector) != nil
  end

  def wait_for_timeout(ms)
    @page.wait_for_timeout(ms)
  end
end

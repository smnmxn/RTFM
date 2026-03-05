import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "emailInput", "submitButton", "formContainer", "successContainer"]
  static values = { url: String }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.handleVideoComplete = this.handleVideoComplete.bind(this)
    window.addEventListener("video-complete", this.handleVideoComplete)
  }

  handleVideoComplete(event) {
    // Check if modal has already been shown this session
    if (sessionStorage.getItem("beta_modal_shown") === "true") {
      return
    }

    // Show modal after 1 second delay
    setTimeout(() => {
      this.open()
      sessionStorage.setItem("beta_modal_shown", "true")
      this.trackEvent("beta_modal_displayed")
    }, 1000)
  }

  open() {
    this.backdropTarget.classList.remove("hidden")
    this.dialogTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.closeOnEscape)
    document.body.classList.add("overflow-hidden")

    // Focus input after DOM has updated
    setTimeout(() => {
      this.emailInputTarget?.focus()
    }, 100)
  }

  close() {
    // Only track dismissal if form is still visible (not after successful submission)
    if (!this.formContainerTarget.classList.contains("hidden")) {
      this.trackEvent("beta_modal_dismissed")
    }

    this.backdropTarget.classList.add("hidden")
    this.dialogTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async submit(event) {
    event.preventDefault()

    const email = this.emailInputTarget.value.trim()

    // Basic email validation
    if (!email || !email.includes("@")) {
      this.emailInputTarget.focus()
      return
    }

    // Disable button and show loading state
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Joining..."

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: new URLSearchParams({ email: email })
      })

      if (response.ok) {
        const data = await response.json()
        this.trackEvent("beta_modal_submitted", { email: email })
        this.trackEvent("beta_modal_conversion")

        // Redirect to questionnaire
        if (data.redirect_url) {
          window.Turbo.visit(data.redirect_url)
        } else if (data.message) {
          // Already completed - show message and close
          this.formContainerTarget.classList.add("hidden")
          this.successContainerTarget.classList.remove("hidden")
          setTimeout(() => {
            this.close()
            this.formContainerTarget.classList.remove("hidden")
            this.successContainerTarget.classList.add("hidden")
            this.emailInputTarget.value = ""
            this.submitButtonTarget.disabled = false
            this.submitButtonTarget.textContent = "Join Waitlist"
          }, 2000)
        }
      } else {
        console.error("Waitlist submission failed:", response.status)
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error("Waitlist submission request failed:", error)
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.textContent = "Join Waitlist"
  }

  trackEvent(eventType, eventData = null) {
    const body = {
      event_type: eventType,
      page_path: window.location.pathname
    }
    if (eventData) {
      body.event_data = eventData
    }

    fetch("/t", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      keepalive: true
    }).catch(() => {})
  }

  disconnect() {
    window.removeEventListener("video-complete", this.handleVideoComplete)
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

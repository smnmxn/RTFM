import { Controller } from "@hotwired/stimulus"

// Compact notification prompt shown during onboarding wait states.
// Hides itself if: dismissed, already granted, or Notification API unavailable.
export default class extends Controller {
  static targets = ["prompt", "granted"]

  static DISMISS_KEY = "notification_prompt_dismissed"

  connect() {
    // Hide entirely if unavailable, already dismissed, or already granted
    if (typeof Notification === "undefined" || !window.isSecureContext) {
      this.element.classList.add("hidden")
      return
    }

    if (localStorage.getItem(this.constructor.DISMISS_KEY)) {
      this.element.classList.add("hidden")
      return
    }

    if (Notification.permission === "granted") {
      this._showGranted()
      return
    }

    if (Notification.permission === "denied") {
      this.element.classList.add("hidden")
      return
    }

    // permission === "default" -- show the prompt
    this.promptTarget.classList.remove("hidden")
  }

  enable() {
    Notification.requestPermission().then((perm) => {
      if (perm === "granted") {
        this._showGranted()
      } else {
        this.dismiss()
      }
    })
  }

  dismiss() {
    localStorage.setItem(this.constructor.DISMISS_KEY, "1")
    this.element.classList.add("hidden")
  }

  _showGranted() {
    this.promptTarget.classList.add("hidden")
    this.grantedTarget.classList.remove("hidden")
    // Auto-hide after a few seconds
    setTimeout(() => {
      this.element.classList.add("hidden")
    }, 3000)
  }
}

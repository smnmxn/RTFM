import { Controller } from "@hotwired/stimulus"

// Notification prompt shown during onboarding wait states.
// Replaces the "please don't close this page" warning with a notification opt-in.
// Falls back to the plain warning if unavailable, dismissed, or denied.
export default class extends Controller {
  static targets = ["prompt", "granted", "fallback"]

  static DISMISS_KEY = "notification_prompt_dismissed"

  connect() {
    // Unavailable (HTTP or no API) -- show fallback
    if (typeof Notification === "undefined" || !window.isSecureContext) {
      this._showFallback()
      return
    }

    // Already dismissed -- show fallback
    if (localStorage.getItem(this.constructor.DISMISS_KEY)) {
      this._showFallback()
      return
    }

    // Already granted -- show confirmation briefly, then fallback
    if (Notification.permission === "granted") {
      this._showGranted()
      return
    }

    // Denied -- show fallback
    if (Notification.permission === "denied") {
      this._showFallback()
      return
    }

    // permission === "default" -- show the prompt
    this._hideFallback()
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
    this.promptTarget.classList.add("hidden")
    this._showFallback()
  }

  _showGranted() {
    this.promptTarget.classList.add("hidden")
    this._hideFallback()
    this.grantedTarget.classList.remove("hidden")
  }

  _showFallback() {
    if (this.hasFallbackTarget) this.fallbackTarget.classList.remove("hidden")
  }

  _hideFallback() {
    if (this.hasFallbackTarget) this.fallbackTarget.classList.add("hidden")
  }
}

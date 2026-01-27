import { Controller } from "@hotwired/stimulus"

// Controls individual toast notifications.
// Auto-dismisses after a delay (unless persistent) with slide-in/out animation.
// Also fires a browser notification if the tab is not focused.
export default class extends Controller {
  static values = {
    persistent: { type: Boolean, default: false },
    autoDismiss: { type: Number, default: 15000 }
  }

  connect() {
    // Slide in
    requestAnimationFrame(() => {
      this.element.classList.remove("translate-x-full", "opacity-0")
      this.element.classList.add("translate-x-0", "opacity-100")
    })

    // Auto-dismiss unless persistent (errors)
    if (!this.persistentValue) {
      this.timeout = setTimeout(() => this.dismiss(), this.autoDismissValue)
    }

    // Enforce max 3 toasts in the container
    this._enforceMax()

    // Fire browser notification if tab is not focused
    this._maybeBrowserNotify()
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    if (this.timeout) clearTimeout(this.timeout)
    this.element.classList.remove("translate-x-0", "opacity-100")
    this.element.classList.add("translate-x-full", "opacity-0")
    setTimeout(() => this.element.remove(), 300)
  }

  _enforceMax() {
    const container = this.element.parentElement
    if (!container) return
    const toasts = container.querySelectorAll("[data-controller='toast']")
    if (toasts.length > 3) {
      // Remove oldest (first in DOM, which is visually at the top since flex-col-reverse)
      toasts[0].remove()
    }
  }

  _maybeBrowserNotify() {
    if (document.visibilityState === "visible") return
    if (typeof Notification === "undefined") return
    if (Notification.permission !== "granted") return

    const message = this.element.querySelector("p")?.textContent
    if (message) {
      new Notification("supportpages.io", { body: message, icon: "/icon.png" })
    }
  }
}

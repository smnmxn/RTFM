import { Controller } from "@hotwired/stimulus"

// Manages browser notification permission via the Notification API.
// Provides a toggle button that requests permission when clicked.
export default class extends Controller {
  static targets = ["toggle", "status"]

  connect() {
    this._updateUI()
  }

  request() {
    if (typeof Notification === "undefined") return

    if (Notification.permission === "default") {
      Notification.requestPermission().then(() => this._updateUI())
    } else if (Notification.permission === "denied") {
      // Can't re-request -- show instructions
      this.statusTarget.textContent = "Blocked by browser. Enable in browser settings."
    }
  }

  _updateUI() {
    if (typeof Notification === "undefined") {
      this.statusTarget.textContent = window.isSecureContext
        ? "Not supported in this browser."
        : "Requires HTTPS. Browser notifications will work in production."
      this.toggleTarget.textContent = "Unavailable"
      this.toggleTarget.disabled = true
      this.toggleTarget.classList.add("bg-gray-100", "text-gray-400")
      return
    }

    const perm = Notification.permission
    if (perm === "granted") {
      this.statusTarget.textContent = "Enabled"
      this.toggleTarget.textContent = "Enabled"
      this.toggleTarget.classList.add("bg-green-100", "text-green-800")
      this.toggleTarget.classList.remove("bg-gray-100", "text-gray-800", "hover:bg-gray-200")
    } else if (perm === "denied") {
      this.statusTarget.innerHTML = 'Blocked by your browser. To enable, click the <strong>lock icon</strong> in the address bar, find <strong>Notifications</strong>, and set it to <strong>Allow</strong>. Then reload this page.'
      this.toggleTarget.textContent = "Blocked"
      this.toggleTarget.disabled = true
      this.toggleTarget.classList.add("bg-red-100", "text-red-800")
    } else {
      this.statusTarget.textContent = "Get notified when background tasks finish, even if the tab is not focused."
      this.toggleTarget.textContent = "Enable"
    }
  }
}

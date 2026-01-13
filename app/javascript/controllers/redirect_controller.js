import { Controller } from "@hotwired/stimulus"

// Handles page redirects triggered by Turbo Stream updates
// Usage: <div data-controller="redirect" data-redirect-url-value="/path/to/redirect">
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (this.urlValue) {
      window.location.href = this.urlValue
    }
  }
}

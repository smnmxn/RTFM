import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Handles page redirects triggered by Turbo Stream updates
// Usage: <div data-controller="redirect" data-redirect-url-value="/path/to/redirect">
export default class extends Controller {
  static values = { url: String, delay: { type: Number, default: 500 } }

  connect() {
    if (this.urlValue) {
      setTimeout(() => {
        Turbo.visit(this.urlValue)
      }, this.delayValue)
    }
  }
}

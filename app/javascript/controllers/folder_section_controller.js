import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chevron", "content"]
  static values = { expanded: { type: Boolean, default: true } }

  connect() {
    this.updateState()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
  }

  expandedValueChanged() {
    this.updateState()
  }

  updateState() {
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-90", this.expandedValue)
      this.chevronTarget.classList.toggle("rotate-0", !this.expandedValue)
    }
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.expandedValue)
    }
  }
}

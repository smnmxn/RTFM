import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { articleId: Number }
  static targets = ["buttons", "thankyou"]

  connect() {
    // Check if user already provided feedback
    const key = this.storageKey
    if (localStorage.getItem(key)) {
      this.showThankyou()
    }
  }

  helpful() {
    this.submitFeedback("helpful")
  }

  notHelpful() {
    this.submitFeedback("not_helpful")
  }

  submitFeedback(type) {
    const key = this.storageKey

    // Prevent duplicate feedback
    if (localStorage.getItem(key)) return

    // Store in localStorage
    localStorage.setItem(key, type)

    // Show thank you message
    this.showThankyou()
  }

  showThankyou() {
    if (this.hasButtonsTarget) {
      this.buttonsTarget.classList.add("hidden")
    }
    if (this.hasThankyouTarget) {
      this.thankyouTarget.classList.remove("hidden")
    }
  }

  get storageKey() {
    return `article_feedback_${this.articleIdValue}`
  }
}

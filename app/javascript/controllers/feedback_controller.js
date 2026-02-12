import { Controller } from "@hotwired/stimulus"
import { animate } from "motion"

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

    // Show thank you message with animation
    this.showThankyouAnimated()
  }

  showThankyouAnimated() {
    if (this.hasButtonsTarget) {
      animate(
        this.buttonsTarget,
        { opacity: [1, 0], transform: ["scale(1)", "scale(0.95)"] },
        { duration: 0.2 }
      ).then(() => {
        this.buttonsTarget.classList.add("hidden")
        if (this.hasThankyouTarget) {
          this.thankyouTarget.classList.remove("hidden")
          animate(
            this.thankyouTarget,
            { opacity: [0, 1], transform: ["scale(0.9)", "scale(1)"] },
            { duration: 0.3, easing: [0.34, 1.56, 0.64, 1] }
          )
        }
      })
    }
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

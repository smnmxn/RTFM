import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.textContent || this.sourceTarget.value

    try {
      await navigator.clipboard.writeText(text)

      // Update button text temporarily
      const originalText = this.buttonTarget.textContent
      this.buttonTarget.textContent = "Copied!"
      this.buttonTarget.classList.add("bg-green-600")
      this.buttonTarget.classList.remove("app-accent-bg")

      setTimeout(() => {
        this.buttonTarget.textContent = originalText
        this.buttonTarget.classList.remove("bg-green-600")
        this.buttonTarget.classList.add("app-accent-bg")
      }, 2000)
    } catch (err) {
      console.error("Failed to copy text:", err)
    }
  }
}

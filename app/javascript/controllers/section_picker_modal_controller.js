import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "select", "submitButton"]
  static values = { url: String }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  open(event) {
    event.preventDefault()
    this.backdropTarget.classList.remove("hidden")
    this.dialogTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.closeOnEscape)
    document.body.classList.add("overflow-hidden")
    this.selectTarget?.focus()
  }

  close() {
    this.backdropTarget.classList.add("hidden")
    this.dialogTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async submit(event) {
    event.preventDefault()
    const sectionId = this.selectTarget.value

    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Approving..."

    try {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      const url = new URL(this.urlValue, window.location.origin)
      if (sectionId) {
        url.searchParams.set("section_id", sectionId)
      }

      const response = await fetch(url.toString(), {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": token
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.close()
        Turbo.renderStreamMessage(html)
      } else {
        console.error("Approve failed:", response.status)
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error("Approve request failed:", error)
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.textContent = "Approve"
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

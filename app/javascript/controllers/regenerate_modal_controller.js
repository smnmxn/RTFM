import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "textarea", "submitButton"]
  static values = { url: String, label: { type: String, default: "Regenerate" } }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  open(event) {
    event.preventDefault()
    this.backdropTarget.classList.remove("hidden")
    this.dialogTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.closeOnEscape)
    document.body.classList.add("overflow-hidden")
    this.textareaTarget?.focus()
  }

  close() {
    this.backdropTarget.classList.add("hidden")
    this.dialogTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
    if (this.hasTextareaTarget) this.textareaTarget.value = ""
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async submit(event) {
    event.preventDefault()
    const guidance = this.hasTextareaTarget ? this.textareaTarget.value.trim() : ""

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = this.labelValue === "Generate" ? "Generating..." : "Regenerating..."
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ regeneration_guidance: guidance })
      })

      if (response.ok) {
        const data = await response.json()
        this.close()
        if (data.redirect_url) {
          window.Turbo.visit(data.redirect_url)
        }
      } else {
        console.error("Regeneration failed:", response.status)
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error("Regeneration request failed:", error)
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = this.labelValue
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

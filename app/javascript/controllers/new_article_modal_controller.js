import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "title", "description", "section", "submitButton"]
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
    this.titleTarget?.focus()
  }

  close() {
    this.backdropTarget.classList.add("hidden")
    this.dialogTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
    // Reset form
    if (this.hasTitleTarget) this.titleTarget.value = ""
    if (this.hasDescriptionTarget) this.descriptionTarget.value = ""
    if (this.hasSectionTarget) this.sectionTarget.value = ""
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async submit(event) {
    event.preventDefault()

    const title = this.hasTitleTarget ? this.titleTarget.value.trim() : ""
    if (!title) {
      this.titleTarget?.focus()
      return
    }

    const description = this.hasDescriptionTarget ? this.descriptionTarget.value.trim() : ""
    const sectionId = this.hasSectionTarget ? this.sectionTarget.value : ""

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = "Creating..."
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          title: title,
          description: description,
          section_id: sectionId
        })
      })

      if (response.ok) {
        const data = await response.json()
        this.close()
        if (data.redirect_url) {
          Turbo.visit(data.redirect_url)
        }
      } else {
        console.error("Article creation failed:", response.status)
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error("Article creation request failed:", error)
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Create Article"
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

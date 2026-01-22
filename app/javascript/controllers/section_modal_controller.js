import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "name", "description", "visible", "submitButton"]
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
    this.nameTarget?.focus()
  }

  close() {
    this.backdropTarget.classList.add("hidden")
    this.dialogTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
    // Reset form
    if (this.hasNameTarget) this.nameTarget.value = ""
    if (this.hasDescriptionTarget) this.descriptionTarget.value = ""
    if (this.hasVisibleTarget) this.visibleTarget.checked = true
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  async submit(event) {
    event.preventDefault()

    const name = this.hasNameTarget ? this.nameTarget.value.trim() : ""
    if (!name) {
      this.nameTarget?.focus()
      return
    }

    const description = this.hasDescriptionTarget ? this.descriptionTarget.value.trim() : ""
    const visible = this.hasVisibleTarget ? this.visibleTarget.checked : true

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
          section: {
            name: name,
            description: description,
            visible: visible
          }
        })
      })

      if (response.ok) {
        const data = await response.json()
        this.close()
        if (data.redirect_url) {
          Turbo.visit(data.redirect_url)
        } else {
          Turbo.visit(window.location.href)
        }
      } else {
        console.error("Section creation failed:", response.status)
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error("Section creation request failed:", error)
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Create Section"
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

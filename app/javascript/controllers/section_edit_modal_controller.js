import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "name", "description", "visible", "submitButton", "icon", "iconGrid"]
  static values = { url: String }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  open(event) {
    event?.preventDefault()
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
  }

  selectIcon(event) {
    event.preventDefault()
    const button = event.currentTarget
    const iconName = button.dataset.icon

    // Update hidden input
    if (this.hasIconTarget) this.iconTarget.value = iconName

    // Update visual selection
    if (this.hasIconGridTarget) {
      this.iconGridTarget.querySelectorAll("button").forEach(btn => {
        btn.classList.remove("ring-2", "ring-indigo-500", "bg-indigo-50")
        btn.classList.add("hover:bg-gray-100")
      })
    }
    button.classList.remove("hover:bg-gray-100")
    button.classList.add("ring-2", "ring-indigo-500", "bg-indigo-50")
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
    const icon = this.hasIconTarget ? this.iconTarget.value : "document-text"

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.textContent = "Saving..."
    }

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({
          section: {
            name: name,
            description: description,
            visible: visible,
            icon: icon
          }
        })
      })

      if (response.ok) {
        const data = await response.json()
        this.close()
        if (data.redirect_url) {
          window.Turbo.visit(data.redirect_url)
        } else {
          window.Turbo.visit(window.location.href)
        }
      } else {
        console.error("Section update failed:", response.status)
        this.resetSubmitButton()
      }
    } catch (error) {
      console.error("Section update request failed:", error)
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.textContent = "Save Changes"
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

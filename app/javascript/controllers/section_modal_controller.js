import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "name", "description", "visible", "submitButton", "icon", "iconGrid"]
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
    // Reset icon to default
    if (this.hasIconTarget) this.iconTarget.value = "document-text"
    if (this.hasIconGridTarget) {
      this.iconGridTarget.querySelectorAll("button").forEach((btn, index) => {
        btn.classList.remove("ring-2", "ring-zinc-500", "bg-zinc-100")
        if (index === 0) {
          btn.classList.add("ring-2", "ring-zinc-500", "bg-zinc-100")
        } else {
          btn.classList.add("hover:app-surface-alt")
        }
      })
    }
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
        btn.classList.remove("ring-2", "ring-zinc-500", "bg-zinc-100")
        btn.classList.add("hover:app-surface-alt")
      })
    }
    button.classList.remove("hover:app-surface-alt")
    button.classList.add("ring-2", "ring-zinc-500", "bg-zinc-100")
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

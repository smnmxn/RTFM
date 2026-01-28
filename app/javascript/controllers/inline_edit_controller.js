import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "input", "saving"]
  static values = {
    url: String,
    field: String,
    saving: { type: Boolean, default: false }
  }

  connect() {
    this.originalValue = this.inputTarget.value
  }

  edit() {
    if (this.savingValue) return

    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    this.inputTarget.focus()
    this.inputTarget.select()

    // Notify inbox controller that editing has started
    this.dispatch("editstart", { bubbles: true })
  }

  async save() {
    const newValue = this.inputTarget.value.trim()

    // Don't save if unchanged
    if (newValue === this.originalValue) {
      this.cancel()
      return
    }

    this.savingValue = true
    this.showSavingIndicator()

    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          field: this.fieldValue,
          value: newValue
        })
      })

      if (response.ok) {
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)
        // Turbo replaces the DOM with fresh server content - no need to call cancel()
      } else {
        this.showError()
        this.cancel()
      }
    } catch (error) {
      console.error("Save failed:", error)
      this.showError()
      this.cancel()
    } finally {
      this.savingValue = false
      this.hideSavingIndicator()
    }
  }

  cancel() {
    this.inputTarget.value = this.originalValue
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")

    // Notify inbox controller that editing has stopped
    this.dispatch("editend", { bubbles: true })
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }

  showSavingIndicator() {
    if (this.hasSavingTarget) {
      this.savingTarget.classList.remove("hidden")
    }
  }

  hideSavingIndicator() {
    if (this.hasSavingTarget) {
      this.savingTarget.classList.add("hidden")
    }
  }

  showError() {
    this.inputTarget.classList.add("border-red-500")
    setTimeout(() => {
      this.inputTarget.classList.remove("border-red-500")
    }, 2000)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

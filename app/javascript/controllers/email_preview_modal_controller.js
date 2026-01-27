import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "backdrop", "iframe", "title"]
  static values = { url: String }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  open(event) {
    event.preventDefault()

    const eventType = event.currentTarget.dataset.eventType
    const eventLabel = event.currentTarget.dataset.eventLabel
    const url = `${this.urlValue}?event_type=${encodeURIComponent(eventType)}`

    this.titleTarget.textContent = eventLabel
    this.iframeTarget.src = url

    this.backdropTarget.classList.remove("hidden")
    this.dialogTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.closeOnEscape)
    document.body.classList.add("overflow-hidden")
  }

  close() {
    this.backdropTarget.classList.add("hidden")
    this.dialogTarget.classList.add("hidden")
    this.iframeTarget.src = ""
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.classList.remove("overflow-hidden")
  }
}

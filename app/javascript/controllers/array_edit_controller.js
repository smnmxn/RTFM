import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list"]
  static values = {
    url: String,
    field: String
  }

  connect() {
    if (this.hasListTarget) {
      this.sortable = Sortable.create(this.listTarget, {
        animation: 150,
        handle: "[data-drag-handle]",
        ghostClass: "opacity-50",
        onEnd: (evt) => this.reorder(evt)
      })
    }
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async reorder(evt) {
    if (evt.oldIndex === evt.newIndex) return

    try {
      const response = await fetch(`${this.urlValue}/reorder_array_item`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          field: this.fieldValue,
          old_index: evt.oldIndex,
          new_index: evt.newIndex
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      } else {
        console.error("Reorder failed")
        window.location.reload()
      }
    } catch (error) {
      console.error("Reorder failed:", error)
    }
  }

  async add() {
    try {
      const response = await fetch(`${this.urlValue}/add_array_item`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          field: this.fieldValue
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Add failed:", error)
    }
  }

  async remove(event) {
    const index = event.params.index

    if (!confirm("Are you sure you want to delete this item?")) {
      return
    }

    try {
      const response = await fetch(`${this.urlValue}/remove_array_item`, {
        method: "DELETE",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          field: this.fieldValue,
          index: index
        })
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Remove failed:", error)
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

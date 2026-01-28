import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static values = {
    deleteUrl: String
  }

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    // Close any other open menus first
    document.querySelectorAll('[data-section-menu-target="menu"]').forEach(menu => {
      if (menu !== this.menuTarget) {
        menu.classList.add("hidden")
      }
    })

    this.menuTarget.classList.toggle("hidden")

    if (!this.menuTarget.classList.contains("hidden")) {
      document.addEventListener("click", this.closeOnClickOutside)
    } else {
      document.removeEventListener("click", this.closeOnClickOutside)
    }
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add("hidden")
      document.removeEventListener("click", this.closeOnClickOutside)
    }
  }

  openEdit(event) {
    event.preventDefault()
    this.menuTarget.classList.add("hidden")

    // Find and open the edit modal within this section row
    const editModalController = this.application.getControllerForElementAndIdentifier(
      this.element.querySelector('[data-controller="section-edit-modal"]'),
      "section-edit-modal"
    )
    if (editModalController) {
      editModalController.open()
    }
  }

  async delete(event) {
    event.preventDefault()
    this.menuTarget.classList.add("hidden")

    if (!confirm("Delete this section? Articles in this section will be moved to Uncategorized.")) {
      return
    }

    try {
      const response = await fetch(this.deleteUrlValue, {
        method: "DELETE",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        }
      })

      if (response.ok) {
        const data = await response.json()
        if (data.redirect_url) {
          window.Turbo.visit(data.redirect_url)
        } else {
          window.Turbo.visit(window.location.href)
        }
      } else {
        console.error("Section deletion failed:", response.status)
        alert("Failed to delete section. Please try again.")
      }
    } catch (error) {
      console.error("Section deletion request failed:", error)
      alert("Failed to delete section. Please try again.")
    }
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }
}

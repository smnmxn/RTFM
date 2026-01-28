import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "placeholder"]
  static values = {
    uploadUrl: String,
    removeUrl: String
  }

  triggerUpload() {
    this.inputTarget.click()
  }

  async upload(event) {
    const file = event.target.files[0]
    if (!file) return
    await this.uploadFile(file)
  }

  dragOver(event) {
    event.preventDefault()
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("ring-2", "ring-indigo-500")
    }
  }

  dragLeave(event) {
    event.preventDefault()
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("ring-2", "ring-indigo-500")
    }
  }

  async drop(event) {
    event.preventDefault()
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("ring-2", "ring-indigo-500")
    }

    const file = event.dataTransfer.files[0]
    if (file && (file.type.startsWith("image/") || file.type === "image/svg+xml")) {
      await this.uploadFile(file)
    }
  }

  async uploadFile(file) {
    const formData = new FormData()
    formData.append("logo", file)

    try {
      const response = await fetch(this.uploadUrlValue, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        },
        body: formData
      })

      if (response.ok) {
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)
      } else {
        this.showError()
      }
    } catch (error) {
      console.error("Logo upload failed:", error)
      this.showError()
    }
  }

  async remove(event) {
    event.preventDefault()
    if (!confirm("Remove logo?")) return

    try {
      const response = await fetch(this.removeUrlValue, {
        method: "DELETE",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken
        }
      })

      if (response.ok) {
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Logo remove failed:", error)
    }
  }

  showError() {
    this.element.classList.add("border-red-500")
    setTimeout(() => {
      this.element.classList.remove("border-red-500")
    }, 2000)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

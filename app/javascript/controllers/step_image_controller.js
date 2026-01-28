import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "placeholder", "uploading"]
  static values = {
    uploadUrl: String,
    removeUrl: String,
    stepIndex: Number
  }

  connect() {
    this.element.addEventListener("dragover", this.dragOver.bind(this))
    this.element.addEventListener("dragleave", this.dragLeave.bind(this))
    this.element.addEventListener("drop", this.drop.bind(this))
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
    this.element.classList.add("ring-2", "ring-indigo-500", "ring-offset-2")
  }

  dragLeave(event) {
    event.preventDefault()
    this.element.classList.remove("ring-2", "ring-indigo-500", "ring-offset-2")
  }

  async drop(event) {
    event.preventDefault()
    this.element.classList.remove("ring-2", "ring-indigo-500", "ring-offset-2")

    const file = event.dataTransfer.files[0]
    if (file && file.type.startsWith("image/")) {
      await this.uploadFile(file)
    }
  }

  async uploadFile(file) {
    this.showUploading()

    const formData = new FormData()
    formData.append("image", file)
    formData.append("step_index", this.stepIndexValue)

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
        this.hideUploading()
      }
    } catch (error) {
      console.error("Upload failed:", error)
      this.showError()
      this.hideUploading()
    }
  }

  async remove(event) {
    event.preventDefault()

    if (!confirm("Remove this image?")) return

    try {
      const separator = this.removeUrlValue.includes('?') ? '&' : '?'
      const response = await fetch(`${this.removeUrlValue}${separator}step_index=${this.stepIndexValue}`, {
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
      console.error("Remove failed:", error)
    }
  }

  showUploading() {
    if (this.hasUploadingTarget) {
      this.uploadingTarget.classList.remove("hidden")
    }
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.add("hidden")
    }
  }

  hideUploading() {
    if (this.hasUploadingTarget) {
      this.uploadingTarget.classList.add("hidden")
    }
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.classList.remove("hidden")
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

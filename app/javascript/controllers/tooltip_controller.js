import { Controller } from "@hotwired/stimulus"
import tippy from "tippy.js"

export default class extends Controller {
  static values = {
    content: String,
    position: { type: String, default: "top" }
  }

  connect() {
    this.instance = tippy(this.element, {
      content: this.contentValue,
      placement: this.positionValue,
      theme: "app",
      arrow: true,
      delay: [200, 0],
      touch: false,
      appendTo: document.body
    })

    // Remove native title to prevent double tooltip
    if (this.element.hasAttribute("title")) {
      this.element.removeAttribute("title")
    }
  }

  disconnect() {
    if (this.instance) {
      this.instance.destroy()
    }
  }

  contentValueChanged() {
    if (this.instance) {
      this.instance.setContent(this.contentValue)
    }
  }
}

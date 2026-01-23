import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { sectionId: String }

  open() {
    document.dispatchEvent(new CustomEvent("new-article-modal:open", {
      detail: { sectionId: this.sectionIdValue }
    }))
  }
}

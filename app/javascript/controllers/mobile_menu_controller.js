import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]

  toggle() {
    const isHidden = this.menuTarget.classList.contains("hidden")
    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    if (this.hasOpenIconTarget) this.openIconTarget.classList.add("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.remove("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
    if (this.hasOpenIconTarget) this.openIconTarget.classList.remove("hidden")
    if (this.hasCloseIconTarget) this.closeIconTarget.classList.add("hidden")
  }
}

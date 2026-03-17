import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "label", "badge", "collapseIcon"]
  static values = { collapsed: Boolean }

  connect() {
    const stored = localStorage.getItem("sidebar_collapsed")
    if (stored === "true") {
      this.collapsedValue = true
    }
    this.applyState()
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    localStorage.setItem("sidebar_collapsed", this.collapsedValue)
    this.applyState()
  }

  applyState() {
    const sidebar = this.hasSidebarTarget ? this.sidebarTarget : this.element
    if (this.collapsedValue) {
      sidebar.style.width = "48px"
      this.labelTargets.forEach(el => el.classList.add("hidden"))
      this.badgeTargets.forEach(el => el.classList.add("hidden"))
      if (this.hasCollapseIconTarget) {
        this.collapseIconTarget.style.transform = "rotate(180deg)"
      }
    } else {
      sidebar.style.width = "200px"
      this.labelTargets.forEach(el => el.classList.remove("hidden"))
      this.badgeTargets.forEach(el => el.classList.remove("hidden"))
      if (this.hasCollapseIconTarget) {
        this.collapseIconTarget.style.transform = ""
      }
    }
  }
}

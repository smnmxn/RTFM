import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = {
    active: { type: String, default: "overview" },
    hash: { type: Boolean, default: false }
  }

  connect() {
    if (this.hashValue && window.location.hash) {
      const hashTab = window.location.hash.substring(1)
      if (this.hasTab(hashTab)) {
        this.activeValue = hashTab
      }
    }
    this.showActiveTab()
  }

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tabsName
    const previousTab = this.activeValue
    this.activeValue = tabName
    this._previousTab = previousTab
  }

  activeValueChanged() {
    this.showActiveTab()
    if (this.hashValue) {
      history.replaceState(null, null, `#${this.activeValue}`)
    }

    // Dispatch event so panels can refresh their content if needed
    this.dispatch("changed", {
      detail: {
        tab: this.activeValue,
        previousTab: this._previousTab
      }
    })
  }

  showActiveTab() {
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabsName === this.activeValue
      tab.classList.toggle("border-indigo-500", isActive)
      tab.classList.toggle("text-indigo-600", isActive)
      tab.classList.toggle("border-transparent", !isActive)
      tab.classList.toggle("text-gray-500", !isActive)
      tab.classList.toggle("hover:text-gray-700", !isActive)
      tab.classList.toggle("hover:border-gray-300", !isActive)
    })

    this.panelTargets.forEach(panel => {
      const isActive = panel.dataset.tabsName === this.activeValue
      panel.classList.toggle("hidden", !isActive)
    })
  }

  hasTab(name) {
    return this.tabTargets.some(tab => tab.dataset.tabsName === name)
  }
}

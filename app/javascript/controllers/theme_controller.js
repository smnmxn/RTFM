import { Controller } from "@hotwired/stimulus"

// Manages dark/light theme toggling with localStorage persistence
// and system preference detection. Attach to any element with
// data-controller="theme" and data-action="click->theme#toggle".
export default class extends Controller {
  connect() {
    this.applyTheme(this.currentTheme)

    // Listen for system preference changes when no explicit preference is stored
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.systemChangeHandler = () => {
      if (!localStorage.getItem("theme")) {
        this.applyTheme(this.currentTheme)
      }
    }
    this.mediaQuery.addEventListener("change", this.systemChangeHandler)
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.systemChangeHandler)
  }

  toggle() {
    const next = this.currentTheme === "dark" ? "light" : "dark"
    localStorage.setItem("theme", next)
    this.applyTheme(next)
  }

  get currentTheme() {
    return localStorage.getItem("theme") ||
      (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
  }

  applyTheme(theme) {
    document.documentElement.classList.toggle("dark", theme === "dark")
  }
}

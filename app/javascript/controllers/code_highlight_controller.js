import { Controller } from "@hotwired/stimulus"
import hljs from "highlight.js"

// Highlights code blocks on connect and when new ones appear via Turbo
export default class extends Controller {
  connect() {
    this.highlightAll()
    this.observer = new MutationObserver(() => this.highlightAll())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  highlightAll() {
    this.element.querySelectorAll("pre code:not([data-highlighted])").forEach((block) => {
      hljs.highlightElement(block)
    })
  }
}

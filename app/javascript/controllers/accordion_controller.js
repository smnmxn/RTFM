import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const item = event.currentTarget.closest("[data-accordion-target='item']")
    const answer = item.querySelector("[data-role='answer']")
    const icon = item.querySelector("[data-role='icon']")

    const isOpen = answer.style.maxHeight && answer.style.maxHeight !== "0px"

    if (isOpen) {
      answer.style.maxHeight = "0px"
      icon.style.transform = "rotate(0deg)"
    } else {
      answer.style.maxHeight = answer.scrollHeight + "px"
      icon.style.transform = "rotate(180deg)"
    }
  }
}

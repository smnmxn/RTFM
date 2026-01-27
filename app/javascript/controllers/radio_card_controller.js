import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  select(event) {
    const selected = event.currentTarget
    this.cardTargets.forEach(card => {
      if (card === selected) {
        card.classList.add("border-indigo-300", "bg-indigo-50")
        card.classList.remove("border-gray-200")
      } else {
        card.classList.remove("border-indigo-300", "bg-indigo-50")
        card.classList.add("border-gray-200")
      }
    })
  }
}

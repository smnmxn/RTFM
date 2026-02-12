import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  select(event) {
    const selected = event.currentTarget
    this.cardTargets.forEach(card => {
      if (card === selected) {
        card.classList.add("card-selected")
        card.classList.remove("card-unselected")
      } else {
        card.classList.remove("card-selected")
        card.classList.add("card-unselected")
      }
    })
  }
}

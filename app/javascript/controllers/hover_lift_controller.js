import { Controller } from "@hotwired/stimulus"
import { animate } from "motion"

export default class extends Controller {
  enter() {
    animate(
      this.element,
      { transform: "translateY(-2px)" },
      { duration: 0.2, easing: [0.25, 0.1, 0.25, 1] }
    )
  }

  leave() {
    animate(
      this.element,
      { transform: "translateY(0px)" },
      { duration: 0.15, easing: [0.25, 0.1, 0.25, 1] }
    )
  }
}

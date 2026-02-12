import { Controller } from "@hotwired/stimulus"
import { animate } from "motion"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 0 },
    duration: { type: Number, default: 0.8 },
    distance: { type: Number, default: 16 }
  }

  connect() {
    this.element.style.opacity = "0"

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            this.reveal()
            this.observer.disconnect()
          }
        })
      },
      { threshold: 0.1 }
    )

    this.observer.observe(this.element)
  }

  reveal() {
    animate(
      this.element,
      { opacity: [0, 1], transform: [`translateY(${this.distanceValue}px)`, "translateY(0px)"] },
      { duration: this.durationValue, delay: this.delayValue / 1000, easing: [0.25, 0.1, 0.25, 1] }
    )
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}

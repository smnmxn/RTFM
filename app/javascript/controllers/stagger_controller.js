import { Controller } from "@hotwired/stimulus"
import { animate } from "motion"

export default class extends Controller {
  static targets = ["item"]
  static values = {
    delay: { type: Number, default: 100 },
    duration: { type: Number, default: 0.8 },
    distance: { type: Number, default: 20 }
  }

  connect() {
    this.animated = false
    this.itemTargets.forEach(el => {
      el.style.opacity = "0"
    })

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting && !this.animated) {
            this.animated = true
            this.animateItems()
            this.observer.disconnect()
          }
        })
      },
      { threshold: 0.1 }
    )

    this.observer.observe(this.element)
  }

  animateItems() {
    this.itemTargets.forEach((el, i) => {
      animate(
        el,
        { opacity: [0, 1], transform: [`translateY(${this.distanceValue}px)`, "translateY(0px)"] },
        { duration: this.durationValue, delay: i * (this.delayValue / 1000), easing: [0.25, 0.1, 0.25, 1] }
      )
    })
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
  }
}

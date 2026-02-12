import { Controller } from "@hotwired/stimulus"
import { animate } from "motion"

export default class extends Controller {
  static targets = ["inner", "glare"]
  static values = { max: { type: Number, default: 12 } }

  connect() {
    this.element.style.perspective = "1200px"
    this.innerTarget.style.transformStyle = "preserve-3d"
    this.disabled = false
  }

  move(event) {
    if (this.disabled) return

    const rect = this.element.getBoundingClientRect()
    const x = (event.clientX - rect.left) / rect.width - 0.5
    const y = (event.clientY - rect.top) / rect.height - 0.5

    animate(this.innerTarget, {
      rotateX: `${-y * this.maxValue}deg`,
      rotateY: `${x * this.maxValue}deg`,
    }, { duration: 0.15 })

    if (this.hasGlareTarget) {
      const px = (x + 0.5) * 100
      const py = (y + 0.5) * 100
      this.glareTarget.style.background =
        `radial-gradient(circle at ${px}% ${py}%, rgba(255,255,255,0.25) 0%, transparent 60%)`
    }
  }

  leave() {
    if (this.disabled) return

    animate(this.innerTarget, {
      rotateX: "0deg",
      rotateY: "0deg",
    }, { type: "spring", stiffness: 200, damping: 15 })

    if (this.hasGlareTarget) {
      this.glareTarget.style.background = "transparent"
    }
  }

  disable() {
    this.disabled = true
    animate(this.innerTarget, {
      rotateX: "0deg",
      rotateY: "0deg",
    }, { duration: 0.3 })
    if (this.hasGlareTarget) {
      this.glareTarget.style.background = "transparent"
    }
  }
}

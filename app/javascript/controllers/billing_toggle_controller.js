import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyBtn", "annualBtn", "monthly", "annual", "intervalField"]

  connect() {
    this.showAnnual()
  }

  selectMonthly() {
    this.monthlyTargets.forEach(el => el.classList.remove("hidden"))
    this.annualTargets.forEach(el => el.classList.add("hidden"))
    this.monthlyBtnTarget.classList.add("bg-white", "text-zinc-900", "shadow-sm")
    this.monthlyBtnTarget.classList.remove("text-zinc-400")
    this.annualBtnTarget.classList.remove("bg-white", "text-zinc-900", "shadow-sm")
    this.annualBtnTarget.classList.add("text-zinc-400")
    this.#setInterval("monthly")
  }

  selectAnnual() {
    this.showAnnual()
  }

  showAnnual() {
    this.annualTargets.forEach(el => el.classList.remove("hidden"))
    this.monthlyTargets.forEach(el => el.classList.add("hidden"))
    this.annualBtnTarget.classList.add("bg-white", "text-zinc-900", "shadow-sm")
    this.annualBtnTarget.classList.remove("text-zinc-400")
    this.monthlyBtnTarget.classList.remove("bg-white", "text-zinc-900", "shadow-sm")
    this.monthlyBtnTarget.classList.add("text-zinc-400")
    this.#setInterval("annual")
  }

  #setInterval(value) {
    if (this.hasIntervalFieldTarget) {
      this.intervalFieldTargets.forEach(el => el.value = value)
    }
  }
}

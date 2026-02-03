import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["poster", "video"]

  play() {
    this.posterTarget.classList.add("hidden")
    this.videoTarget.classList.remove("hidden")
    this.videoTarget.play()
  }
}

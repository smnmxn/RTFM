import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["poster", "video"]

  play() {
    this.posterTarget.classList.add("hidden")
    this.videoTarget.muted = false
    this.videoTarget.loop = false
    this.videoTarget.controls = true
    this.videoTarget.currentTime = 0
    this.videoTarget.play()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["poster", "video"]

  connect() {
    // Autoplay doesn't fire on Turbo navigation, so trigger it manually
    if (this.hasVideoTarget && this.videoTarget.paused) {
      this.videoTarget.play().catch(() => {})
    }
  }

  play() {
    this.posterTarget.classList.add("hidden")
    this.videoTarget.muted = false
    this.videoTarget.loop = false
    this.videoTarget.controls = true
    this.videoTarget.currentTime = 0
    this.videoTarget.play()

    // Enable captions by default
    const tracks = this.videoTarget.textTracks
    for (let i = 0; i < tracks.length; i++) {
      if (tracks[i].kind === "captions") {
        tracks[i].mode = "showing"
      }
    }

    this.dispatch("played")
  }
}

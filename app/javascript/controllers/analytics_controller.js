import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.milestonesReached = new Set()
  }

  track(event) {
    const element = event.currentTarget
    const eventType = element.dataset.analyticsEvent
    if (!eventType) return

    let eventData = null
    if (element.dataset.analyticsData) {
      try {
        eventData = JSON.parse(element.dataset.analyticsData)
      } catch (e) {
        // ignore malformed JSON
      }
    }

    this.sendEvent(eventType, eventData)
  }

  // Called via data-action="video-player:played->analytics#videoPlayed"
  videoPlayed(event) {
    const video = event.target.querySelector("video")
    if (!video) return

    this.sendEvent("video_play", { duration: Math.round(video.duration || 0) })

    video.addEventListener("timeupdate", () => {
      if (!video.duration) return
      const progress = (video.currentTime / video.duration) * 100
      const milestones = [25, 50, 75]
      for (const milestone of milestones) {
        if (progress >= milestone && !this.milestonesReached.has(milestone)) {
          this.milestonesReached.add(milestone)
          this.sendEvent("video_progress", {
            progress: milestone,
            current_time: Math.round(video.currentTime),
            duration: Math.round(video.duration)
          })
        }
      }
    })

    video.addEventListener("ended", () => {
      if (!this.milestonesReached.has(100)) {
        this.milestonesReached.add(100)
        this.sendEvent("video_progress", {
          progress: 100,
          current_time: Math.round(video.duration),
          duration: Math.round(video.duration)
        })

        // Dispatch custom event for beta modal trigger
        window.dispatchEvent(new CustomEvent("video-complete", {
          detail: { duration: Math.round(video.duration) }
        }))
      }
    })
  }

  sendEvent(eventType, eventData) {
    const body = {
      event_type: eventType,
      page_path: window.location.pathname
    }
    if (eventData) body.event_data = eventData

    fetch("/t", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
      keepalive: true
    }).catch(() => {})
  }
}

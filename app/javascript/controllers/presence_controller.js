import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  connect() {
    this.consumer = createConsumer()
    this.channel = this.consumer.subscriptions.create("PresenceChannel", {
      connected: () => {
        console.log("[Presence] connected")
        this._startHeartbeat()
      },
      disconnected: () => {
        console.log("[Presence] disconnected")
        this._stopHeartbeat()
      }
    })
  }

  disconnect() {
    this._stopHeartbeat()
    if (this.channel) {
      this.channel.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
  }

  _startHeartbeat() {
    this._stopHeartbeat()
    // Send heartbeat every 30 seconds to keep the Redis key alive (TTL is 60s)
    this.heartbeatInterval = setInterval(() => {
      this.channel.perform("heartbeat")
    }, 30000)
  }

  _stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval)
      this.heartbeatInterval = null
    }
  }
}

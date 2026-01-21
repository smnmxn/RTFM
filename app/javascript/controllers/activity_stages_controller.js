import { Controller } from "@hotwired/stimulus"

// Displays sequential activity stages as a visual checklist
// Usage:
//   <div data-controller="activity-stages"
//        data-activity-stages-stages-value='["Stage 1...", "Stage 2...", "Stage 3..."]'
//        data-activity-stages-duration-value="30">
//     <div data-activity-stages-target="stage" data-state="pending">...</div>
//     <div data-activity-stages-target="stage" data-state="pending">...</div>
//   </div>
//
// Stages progress every `duration` seconds (default 20s)
// States: completed (green check), active (spinner), pending (empty circle)

export default class extends Controller {
  static targets = ["stage", "message"]
  static values = {
    stages: Array,      // Array of stage messages
    duration: { type: Number, default: 20 },  // Seconds per stage
    startTime: Number   // Optional: Unix timestamp when operation started
  }

  connect() {
    this.currentStageIndex = -1
    this.startedAt = this.hasStartTimeValue ? this.startTimeValue * 1000 : Date.now()

    // Calculate initial stage based on elapsed time
    this.updateStages()

    // Update every second
    this.interval = setInterval(() => this.updateStages(), 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  updateStages() {
    if (!this.hasStagesValue || this.stagesValue.length === 0) return

    const elapsed = (Date.now() - this.startedAt) / 1000
    const newStageIndex = Math.min(
      Math.floor(elapsed / this.durationValue),
      this.stagesValue.length - 1
    )

    // Only update DOM if stage changed
    if (newStageIndex !== this.currentStageIndex) {
      this.currentStageIndex = newStageIndex
      this.renderStageStates()
    }
  }

  renderStageStates() {
    // Update stage targets if they exist (checklist mode)
    if (this.hasStageTarget) {
      this.stageTargets.forEach((el, index) => {
        let state
        if (index < this.currentStageIndex) {
          state = 'completed'
        } else if (index === this.currentStageIndex) {
          state = 'active'
        } else {
          state = 'pending'
        }

        el.dataset.state = state

        // Directly control icon visibility
        const completedIcon = el.querySelector('.stage-completed')
        const activeIcon = el.querySelector('.stage-active')
        const pendingIcon = el.querySelector('.stage-pending')
        const textEl = el.querySelector('.stage-text')

        if (completedIcon) completedIcon.style.display = state === 'completed' ? 'block' : 'none'
        if (activeIcon) activeIcon.style.display = state === 'active' ? 'block' : 'none'
        if (pendingIcon) pendingIcon.style.display = state === 'pending' ? 'block' : 'none'

        // Update text styling
        if (textEl) {
          textEl.classList.remove('text-slate-500', 'text-slate-900', 'text-slate-400', 'font-medium')
          if (state === 'completed') {
            textEl.classList.add('text-slate-500')
          } else if (state === 'active') {
            textEl.classList.add('text-slate-900', 'font-medium')
          } else {
            textEl.classList.add('text-slate-400')
          }
        }
      })
    }

    // Also update message target if it exists (legacy single-line mode)
    if (this.hasMessageTarget) {
      const message = this.stagesValue[this.currentStageIndex]
      this.messageTarget.style.opacity = '0'
      setTimeout(() => {
        this.messageTarget.textContent = message
        this.messageTarget.style.opacity = '1'
      }, 150)
    }
  }
}

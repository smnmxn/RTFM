import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "completionCard", "input", "checkbox", "dot", "nextButton", "skipButton"]
  static values = {
    saveUrl: String,
    currentIndex: { type: Number, default: 0 }
  }

  connect() {
    console.log('[onboarding-questions] Controller connected')
    this.totalCards = this.cardTargets.length
    this.updateUI()
  }

  disconnect() {
    console.log('[onboarding-questions] Controller DISCONNECTED - DOM was replaced!')
  }

  selectOption(event) {
    // Radio button selection - enable next button
    this.nextButtonTarget.disabled = false
  }

  toggleCheckbox(event) {
    // Checkbox selection - enable next if at least one is checked
    const checkboxes = event.currentTarget.closest('[data-question]').querySelectorAll('input[type="checkbox"]')
    const anyChecked = Array.from(checkboxes).some(cb => cb.checked)
    this.nextButtonTarget.disabled = !anyChecked
  }

  async next() {
    // Show loading state
    const originalText = this.nextButtonTarget.textContent
    this.nextButtonTarget.disabled = true
    this.nextButtonTarget.innerHTML = `<span class="inline-block w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin mr-2"></span>Saving...`

    // Save current answer
    await this.saveCurrentAnswer()

    // Restore button
    this.nextButtonTarget.innerHTML = originalText

    // Move to next card or complete
    if (this.currentIndexValue < this.totalCards - 1) {
      this.currentIndexValue++
      this.updateUI()
    } else {
      // Last question answered - reload to show checklist
      window.location.reload()
    }
  }

  async skip() {
    // Move to next card without saving
    if (this.currentIndexValue < this.totalCards - 1) {
      this.currentIndexValue++
      this.updateUI()
    } else {
      // Last question skipped - reload to show checklist
      window.location.reload()
    }
  }

  async saveCurrentAnswer() {
    const currentCard = this.cardTargets[this.currentIndexValue]
    const questionKey = currentCard.dataset.question

    let value
    const radios = currentCard.querySelectorAll('input[type="radio"]:checked')
    const checkboxes = currentCard.querySelectorAll('input[type="checkbox"]:checked')

    if (radios.length > 0) {
      value = radios[0].value
    } else if (checkboxes.length > 0) {
      value = Array.from(checkboxes).map(cb => cb.value)
    }

    if (!value || (Array.isArray(value) && value.length === 0)) {
      return
    }

    const payload = { context: {} }
    payload.context[questionKey] = value

    try {
      const response = await fetch(this.saveUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(payload)
      })

      if (!response.ok) {
        console.error('Failed to save context')
      }
    } catch (error) {
      console.error('Error saving context:', error)
    }
  }

  updateUI() {
    // Update card positions
    this.cardTargets.forEach((card, index) => {
      card.classList.remove('translate-x-full', '-translate-x-full')

      if (index < this.currentIndexValue) {
        card.classList.add('-translate-x-full')
      } else if (index > this.currentIndexValue) {
        card.classList.add('translate-x-full')
      }
    })

    // Update progress dots
    this.dotTargets.forEach((dot, index) => {
      dot.classList.toggle('bg-violet-600', index <= this.currentIndexValue)
      dot.classList.toggle('bg-slate-300', index > this.currentIndexValue)
    })

    // Reset next button state for new card
    this.nextButtonTarget.disabled = true

    // Check if current card has a selection
    const currentCard = this.cardTargets[this.currentIndexValue]
    if (currentCard) {
      const hasRadioSelection = currentCard.querySelector('input[type="radio"]:checked')
      const hasCheckboxSelection = currentCard.querySelector('input[type="checkbox"]:checked')
      this.nextButtonTarget.disabled = !hasRadioSelection && !hasCheckboxSelection
    }

    // Update button text on last card
    if (this.currentIndexValue === this.totalCards - 1) {
      this.nextButtonTarget.textContent = 'Done'
    } else {
      this.nextButtonTarget.textContent = 'Next'
    }
  }

  showCompletion() {
    // Hide all question cards
    this.cardTargets.forEach(card => {
      card.classList.add('-translate-x-full')
    })

    // Show completion card
    this.completionCardTarget.classList.remove('translate-x-full')

    // Hide navigation
    this.skipButtonTarget.classList.add('invisible')
    this.nextButtonTarget.classList.add('hidden')

    // Update all dots to completed
    this.dotTargets.forEach(dot => {
      dot.classList.add('bg-violet-600')
      dot.classList.remove('bg-slate-300')
    })
  }
}

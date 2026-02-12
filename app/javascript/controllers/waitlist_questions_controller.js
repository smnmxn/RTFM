import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "completionCard", "input", "textInput", "dot", "nextButton", "skipButton"]
  static values = {
    saveUrl: String,
    redirectUrl: String,
    currentIndex: { type: Number, default: 0 }
  }

  connect() {
    this.totalCards = this.cardTargets.length
    this.updateUI()
  }

  selectOption(event) {
    // Radio button selection - enable next button
    this.nextButtonTarget.disabled = false
  }

  validateText(event) {
    // Text input validation - enable next if required fields are filled
    const currentCard = this.cardTargets[this.currentIndexValue]
    const nameInput = currentCard.querySelector('input[name="name"]')
    const companyInput = currentCard.querySelector('input[name="company"]')

    // Name and company are required, website is optional
    const isValid = nameInput?.value.trim().length > 0 && companyInput?.value.trim().length > 0
    this.nextButtonTarget.disabled = !isValid
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
      // Last question answered - mark as completed and redirect
      await this.markCompleted()
      this.showCompletion()
      setTimeout(() => {
        window.location.href = this.redirectUrlValue
      }, 1500)
    }
  }

  async skip() {
    // Move to next card without saving
    if (this.currentIndexValue < this.totalCards - 1) {
      this.currentIndexValue++
      this.updateUI()
    } else {
      // Last question skipped - mark as completed and redirect
      await this.markCompleted()
      this.showCompletion()
      setTimeout(() => {
        window.location.href = this.redirectUrlValue
      }, 1500)
    }
  }

  async saveCurrentAnswer() {
    const currentCard = this.cardTargets[this.currentIndexValue]
    const cardType = currentCard.dataset.cardType
    const payload = {}

    if (cardType === 'text') {
      // Text input card - collect all text inputs
      const textInputs = currentCard.querySelectorAll('input[type="text"], input[type="url"]')
      textInputs.forEach(input => {
        if (input.value.trim()) {
          payload[input.name] = input.value.trim()
        }
      })
    } else {
      // Radio button card
      const checked = currentCard.querySelector('input[type="radio"]:checked')
      if (!checked) return

      const questionKey = currentCard.dataset.question
      payload[questionKey] = checked.value
    }

    if (Object.keys(payload).length === 0) return

    try {
      await fetch(this.saveUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(payload)
      })
    } catch (error) {
      console.error('Error saving answer:', error)
    }
  }

  async markCompleted() {
    try {
      await fetch(this.saveUrlValue, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ completed: 'true' })
      })
    } catch (error) {
      console.error('Error marking completed:', error)
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
      dot.classList.toggle('bg-zinc-700', index <= this.currentIndexValue)
      dot.classList.toggle('bg-slate-300', index > this.currentIndexValue)
    })

    // Reset next button state for new card
    this.nextButtonTarget.disabled = true

    // Check if current card has valid input
    const currentCard = this.cardTargets[this.currentIndexValue]
    if (currentCard) {
      const cardType = currentCard.dataset.cardType

      if (cardType === 'text') {
        // Text card - check if required fields are filled
        const nameInput = currentCard.querySelector('input[name="name"]')
        const companyInput = currentCard.querySelector('input[name="company"]')
        const isValid = nameInput?.value.trim().length > 0 && companyInput?.value.trim().length > 0
        this.nextButtonTarget.disabled = !isValid
      } else {
        // Radio card - check if an option is selected
        const hasRadioSelection = currentCard.querySelector('input[type="radio"]:checked')
        this.nextButtonTarget.disabled = !hasRadioSelection
      }
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
      dot.classList.add('bg-zinc-700')
      dot.classList.remove('bg-slate-300')
    })
  }
}

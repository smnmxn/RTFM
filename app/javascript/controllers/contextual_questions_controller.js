import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "completionCard", "radio", "checkbox", "textInput", "dot", "nextButton", "skipButton"]
  static values = {
    saveUrl: String,
    total: Number,
    currentIndex: { type: Number, default: 0 }
  }

  connect() {
    this.answers = {}
    this.updateUI()
  }

  selectOption(event) {
    const card = event.currentTarget.closest('[data-question-id]')
    const isMultiSelect = card.dataset.multiSelect === 'true'

    if (isMultiSelect) {
      // For checkboxes, enable next if at least one is checked
      const checkboxes = card.querySelectorAll('input[type="checkbox"]')
      const anyChecked = Array.from(checkboxes).some(cb => cb.checked)
      this.nextButtonTarget.disabled = !anyChecked
    } else {
      // For radio buttons, always enable next when one is selected
      this.nextButtonTarget.disabled = false
    }
  }

  onTextInput(event) {
    // Enable next button if text has content
    const hasContent = event.target.value.trim().length > 0
    this.nextButtonTarget.disabled = !hasContent
  }

  async next() {
    // Save current answer
    await this.saveCurrentAnswer()

    // Move to next card
    if (this.currentIndexValue < this.totalValue - 1) {
      this.currentIndexValue++
      this.updateUI()
    } else {
      // Show completion card
      this.showCompletion()
    }
  }

  async skip() {
    // Move to next card without saving
    if (this.currentIndexValue < this.totalValue - 1) {
      this.currentIndexValue++
      this.updateUI()
    } else {
      this.showCompletion()
    }
  }

  async saveCurrentAnswer() {
    const currentCard = this.cardTargets[this.currentIndexValue]
    if (!currentCard) return

    const questionId = currentCard.dataset.questionId
    const isMultiSelect = currentCard.dataset.multiSelect === 'true'

    let value

    // Check for text input
    const textInput = currentCard.querySelector('textarea')
    if (textInput) {
      value = textInput.value.trim()
    } else if (isMultiSelect) {
      // Checkboxes
      const checked = currentCard.querySelectorAll('input[type="checkbox"]:checked')
      value = Array.from(checked).map(cb => cb.value)
    } else {
      // Radio buttons
      const checked = currentCard.querySelector('input[type="radio"]:checked')
      value = checked?.value
    }

    if (!value || (Array.isArray(value) && value.length === 0)) {
      return
    }

    // Store answer locally
    this.answers[questionId] = value

    // Save to server
    const payload = {
      context: {
        contextual_answers: this.answers
      }
    }

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
        console.error('Failed to save contextual answer')
      }
    } catch (error) {
      console.error('Error saving contextual answer:', error)
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
      const textInput = currentCard.querySelector('textarea')
      const hasTextContent = textInput && textInput.value.trim().length > 0

      this.nextButtonTarget.disabled = !hasRadioSelection && !hasCheckboxSelection && !hasTextContent
    }

    // Update button text on last card
    if (this.currentIndexValue === this.totalValue - 1) {
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

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "picker"]

  syncFromPicker(event) {
    const color = event.target.value
    if (this.hasInputTarget) {
      this.inputTarget.value = color
    }
    this.updatePreview()
  }

  syncFromInput(event) {
    const color = event.target.value
    if (this.hasPickerTarget && this.isValidHex(color)) {
      this.pickerTarget.value = color
    }
    this.updatePreview()
  }

  isValidHex(color) {
    return /^#[0-9a-fA-F]{6}$/.test(color)
  }

  updatePreview() {
    const preview = document.getElementById("color_preview")
    if (!preview) return

    const primaryInput = document.getElementById("project_primary_color")
    const accentInput = document.getElementById("project_accent_color")

    if (primaryInput && accentInput) {
      const primary = this.isValidHex(primaryInput.value) ? primaryInput.value : "#4f46e5"
      const accent = this.isValidHex(accentInput.value) ? accentInput.value : "#7c3aed"
      preview.style.background = `linear-gradient(to right, ${primary}, ${accent})`
    }
  }
}

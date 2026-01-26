import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { mode: { type: String, default: "single" } }
  static targets = ["submitButton", "hint", "searchInput", "repoItem", "repoList", "noResults", "checkbox", "toggleLink", "connectButton", "multiForm"]

  connect() {
    this.updateUI()
  }

  // Toggle between single and multi mode
  toggleMode() {
    this.modeValue = this.modeValue === "single" ? "multi" : "single"
    this.updateUI()
  }

  updateUI() {
    const isMulti = this.modeValue === "multi"

    // Show/hide checkboxes
    this.checkboxTargets.forEach(cb => {
      cb.classList.toggle("hidden", !isMulti)
    })

    // Show/hide connect buttons (single mode)
    this.connectButtonTargets.forEach(btn => {
      btn.classList.toggle("hidden", isMulti)
    })

    // Hide repos connected to other projects in multi mode
    this.repoItemTargets.forEach(item => {
      const connectedToOther = item.dataset.connectedToOther === "true"
      if (connectedToOther) {
        item.classList.toggle("hidden", isMulti)
      }
    })

    // Show/hide multi-select submit button
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.classList.toggle("hidden", !isMulti)
    }

    // Show/hide multi-select form
    if (this.hasMultiFormTarget) {
      this.multiFormTarget.classList.toggle("hidden", !isMulti)
    }

    // Update toggle link text
    if (this.hasToggleLinkTarget) {
      this.toggleLinkTarget.textContent = isMulti
        ? "Back to single repository"
        : "Need to connect multiple repositories?"
    }

    // Update hint and button state
    this.updateButton()
  }

  // Called when checkbox is toggled in multi mode
  checkboxChanged(event) {
    this.updateButton()
  }

  filter() {
    const searchTerm = this.hasSearchInputTarget ? this.searchInputTarget.value.toLowerCase().trim() : ""
    const isMulti = this.modeValue === "multi"
    let visibleCount = 0

    this.repoItemTargets.forEach(item => {
      const repoName = item.dataset.repoName || ""
      const repoDescription = item.dataset.repoDescription || ""
      const connectedToOther = item.dataset.connectedToOther === "true"

      // In multi mode, always hide repos connected to other projects
      if (isMulti && connectedToOther) {
        item.classList.add("hidden")
        return
      }

      const matches = searchTerm === "" ||
                      repoName.includes(searchTerm) ||
                      repoDescription.includes(searchTerm)

      item.classList.toggle("hidden", !matches)
      if (matches) visibleCount++
    })

    // Show/hide no results message
    if (this.hasNoResultsTarget) {
      this.noResultsTarget.classList.toggle("hidden", visibleCount > 0)
    }

    // Hide the repo list divider styling when all items are hidden
    if (this.hasRepoListTarget) {
      this.repoListTarget.classList.toggle("hidden", visibleCount === 0)
    }
  }

  updateButton() {
    if (this.modeValue === "single") {
      // Single mode: no submit button, hint is empty
      if (this.hasHintTarget) {
        this.hintTarget.textContent = ""
      }
      return
    }

    // Multi mode: count checked checkboxes
    const checkedCount = this.checkboxTargets.filter(cb => cb.checked && !cb.disabled).length
    const alreadyConnected = this.checkboxTargets.filter(cb => cb.checked && cb.disabled).length

    if (this.hasSubmitButtonTarget) {
      const hasNewSelections = checkedCount > 0
      const hasExistingConnections = alreadyConnected > 0

      this.submitButtonTarget.disabled = !hasNewSelections && !hasExistingConnections

      if (hasNewSelections) {
        const totalSelected = checkedCount + alreadyConnected
        this.submitButtonTarget.textContent = totalSelected === 1
          ? "Continue with 1 repository"
          : `Continue with ${totalSelected} repositories`
      } else if (hasExistingConnections) {
        this.submitButtonTarget.textContent = alreadyConnected === 1
          ? "Continue with 1 repository"
          : `Continue with ${alreadyConnected} repositories`
      } else {
        this.submitButtonTarget.textContent = "Continue"
      }
    }

    // Update hint text
    if (this.hasHintTarget) {
      if (alreadyConnected > 0) {
        this.hintTarget.textContent = "Select additional repositories to include"
      } else {
        this.hintTarget.textContent = "Select at least one repository"
      }
    }
  }
}

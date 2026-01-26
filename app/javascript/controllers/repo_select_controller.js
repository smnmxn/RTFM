import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "hint", "searchInput", "repoItem", "repoList", "noResults"]

  connect() {
    this.updateButton()
  }

  filter() {
    const searchTerm = this.hasSearchInputTarget ? this.searchInputTarget.value.toLowerCase().trim() : ""
    let visibleCount = 0

    this.repoItemTargets.forEach(item => {
      const repoName = item.dataset.repoName || ""
      const repoDescription = item.dataset.repoDescription || ""
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
    const checkboxes = this.element.querySelectorAll('input[type="checkbox"]:not(:disabled)')
    const checkedCount = Array.from(checkboxes).filter(cb => cb.checked).length
    const alreadyConnected = this.element.querySelectorAll('input[type="checkbox"]:disabled:checked').length

    if (this.hasSubmitButtonTarget) {
      // Enable button if at least one (new) checkbox is selected, OR if there are already connected repos
      const hasNewSelections = checkedCount > 0
      const hasExistingConnections = alreadyConnected > 0

      this.submitButtonTarget.disabled = !hasNewSelections && !hasExistingConnections

      // Update button text based on selection
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
  }
}

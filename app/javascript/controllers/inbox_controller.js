import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor", "notification", "notificationContainer"]
  static values = {
    selectedType: String,
    selectedId: String,
    editing: { type: Boolean, default: false }
  }

  connect() {
    // Listen for morph events to preserve state
    this.boundBeforeMorph = this.beforeMorph.bind(this)
    document.addEventListener("turbo:before-morph-element", this.boundBeforeMorph)

    // Listen for tab changes to refresh when inbox becomes visible
    this.boundTabChanged = this.handleTabChange.bind(this)
    document.addEventListener("tabs:changed", this.boundTabChanged)

    // Listen for edit events from inline-edit controllers
    this.element.addEventListener("inline-edit:editstart", () => this.startEditing())
    this.element.addEventListener("inline-edit:editend", () => this.stopEditing())

    // Set up mutation observer to detect article update notifications
    this.setupNotificationObserver()
  }

  disconnect() {
    document.removeEventListener("turbo:before-morph-element", this.boundBeforeMorph)
    document.removeEventListener("tabs:changed", this.boundTabChanged)
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }
  }

  // When switching to inbox tab, refresh the articles list
  handleTabChange(event) {
    if (event.detail.tab === "inbox") {
      this.refreshArticlesList()
    }
  }

  async refreshArticlesList() {
    const projectSlug = this.element.dataset.projectSlug
    if (!projectSlug) return

    try {
      const response = await fetch(`/projects/${projectSlug}/inbox_articles`, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)

        // After refresh, select the first item if nothing is selected
        requestAnimationFrame(() => this.selectFirstItemIfNeeded())
      }
    } catch (error) {
      console.error("Failed to refresh inbox articles:", error)
    }
  }

  selectFirstItemIfNeeded() {
    // Find the first clickable link in the articles or recommendations list
    const firstLink = this.element.querySelector("#articles-list a, #recommendations-list a")
    if (firstLink) {
      firstLink.click()
    }
  }

  // Called when user starts editing (triggered from inline-edit controllers)
  startEditing() {
    this.editingValue = true
  }

  stopEditing() {
    this.editingValue = false
  }

  // Prevent morphing editor when user is editing
  beforeMorph(event) {
    // If user is editing and the morph target is inside the editor, prevent it
    if (this.editingValue && this.hasEditorTarget && this.editorTarget.contains(event.target)) {
      event.preventDefault()
    }
  }

  // Set up observer to watch for article update notifications appended via broadcast
  setupNotificationObserver() {
    if (!this.hasNotificationContainerTarget) return

    this.mutationObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === Node.ELEMENT_NODE && node.dataset.articleUpdatedId) {
            this.handleArticleUpdate(node.dataset.articleUpdatedId, node.dataset.status)
            // Remove the notification element after processing
            node.remove()
          }
        })
      })
    })

    this.mutationObserver.observe(this.notificationContainerTarget, { childList: true })
  }

  // Handle broadcast notification that article was updated
  handleArticleUpdate(articleId, status) {
    // If viewing this article and it just completed
    if (this.selectedIdValue === articleId && status === "generation_completed") {
      // Check if we're currently showing the "generating" state
      const editorContent = this.hasEditorTarget ? this.editorTarget.querySelector("[data-article-generation-status]") : null
      const wasGenerating = editorContent?.dataset.articleGenerationStatus === "generation_running"

      if (wasGenerating) {
        // Auto-refresh since user is waiting for content
        this.refreshEditor()
      } else {
        // Show prompt since user may be reviewing/editing
        this.showRefreshPrompt()
      }
    }
  }

  showRefreshPrompt() {
    if (this.hasNotificationTarget) {
      this.notificationTarget.classList.remove("hidden")
    }
  }

  hideRefreshPrompt() {
    if (this.hasNotificationTarget) {
      this.notificationTarget.classList.add("hidden")
    }
  }

  refreshEditor() {
    // Reload just the editor frame by clicking the currently selected row
    const selectedRow = this.element.querySelector(`[data-article-id="${this.selectedIdValue}"] a`)
    if (selectedRow) {
      selectedRow.click()
    }
    this.hideRefreshPrompt()
  }

  // Update selection when user clicks a row
  selectItem(event) {
    const row = event.currentTarget.closest("[data-article-id], [data-recommendation-id]")
    if (row) {
      if (row.dataset.articleId) {
        this.selectedTypeValue = "article"
        this.selectedIdValue = row.dataset.articleId
      } else if (row.dataset.recommendationId) {
        this.selectedTypeValue = "recommendation"
        this.selectedIdValue = row.dataset.recommendationId
      }
    }
    // Hide any pending refresh notification since user is navigating
    this.hideRefreshPrompt()
  }
}

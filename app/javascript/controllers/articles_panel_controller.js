import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    selectedArticleId: String
  }

  connect() {
    this.sectionCollapseState = new Map()
    this.setupTreeObserver()
  }

  disconnect() {
    if (this.treeObserver) {
      this.treeObserver.disconnect()
    }
  }

  // Track which article the user selects
  selectArticle(event) {
    const row = event.currentTarget.closest("[data-article-id]")
    if (row) {
      this.selectedArticleIdValue = row.dataset.articleId
    }
  }

  // Save section collapse state when user toggles a section
  saveCollapseState() {
    this.element.querySelectorAll('[data-controller*="folder-section"]').forEach(section => {
      const sectionId = section.id
      const content = section.querySelector('[data-folder-section-target="content"]')
      if (content && sectionId) {
        this.sectionCollapseState.set(sectionId, !content.classList.contains("hidden"))
      }
    })
  }

  // Called when a section toggle is clicked — save state after the toggle completes
  trackSectionToggle() {
    requestAnimationFrame(() => this.saveCollapseState())
  }

  setupTreeObserver() {
    const tree = this.element.querySelector("#articles-folder-tree")
    if (!tree) return

    this.treeObserver = new MutationObserver(() => {
      if (this._treeUpdateFrame) cancelAnimationFrame(this._treeUpdateFrame)
      this._treeUpdateFrame = requestAnimationFrame(() => {
        this.preserveSelection()
        this.restoreCollapseState()
      })
    })

    this.treeObserver.observe(tree, { childList: true, subtree: true })
  }

  // After a folder tree replacement, re-apply the correct selection highlight
  preserveSelection() {
    // Check if any row already has a server-set selection (from turbo_stream response)
    const alreadySelected = this.element.querySelector('[data-controller="folder-article"].row-selected')
    if (alreadySelected) {
      this.selectedArticleIdValue = alreadySelected.dataset.articleId
      return
    }

    // No server-set selection — re-apply from tracked value (background broadcast case)
    if (!this.selectedArticleIdValue) return

    const row = this.element.querySelector(`#folder_article_${this.selectedArticleIdValue}`)
    if (!row) return

    row.classList.remove("row-unselected")
    row.classList.add("row-selected")
  }

  // After a folder tree replacement, restore section collapse/expand state
  restoreCollapseState() {
    if (this.sectionCollapseState.size === 0) return

    this.element.querySelectorAll('[data-controller*="folder-section"]').forEach(section => {
      const sectionId = section.id
      if (this.sectionCollapseState.has(sectionId)) {
        const expanded = this.sectionCollapseState.get(sectionId)
        // Set the Stimulus value attribute — the folder-section controller
        // picks this up via expandedValueChanged and updates the DOM
        section.setAttribute("data-folder-section-expanded-value", expanded.toString())
      }
    })
  }
}

import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String, section: String, group: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      ghostClass: "sortable-ghost",
      handle: "[data-sortable-handle]",
      filter: "a",
      preventOnFilter: false,
      group: this.hasGroupValue ? this.groupValue : undefined,
      onEnd: (evt) => this.persistOrder(evt)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  persistOrder(evt) {
    const fromSection = evt.from.dataset.sortableSectionValue
    const toSection = evt.to.dataset.sortableSectionValue
    const articleId = evt.item.dataset.articleId

    // Check if anything changed (position or section)
    const sectionChanged = fromSection !== toSection
    const positionChanged = evt.oldIndex !== evt.newIndex

    if (!sectionChanged && !positionChanged) return

    // Get new order for target section
    const articleIds = Array.from(evt.to.children)
      .map(row => row.dataset.articleId)
      .filter(Boolean)

    // Update the article's data-section-id attribute if it moved sections
    if (sectionChanged) {
      evt.item.dataset.sectionId = toSection
    }

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({
        article_ids: articleIds,
        section_id: toSection === "uncategorized" ? null : toSection,
        moved_article_id: sectionChanged ? articleId : null
      })
    })
  }
}

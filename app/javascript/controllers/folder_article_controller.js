import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    // Remove selection from all articles
    document.querySelectorAll('[data-controller="folder-article"]').forEach(el => {
      el.classList.remove('row-selected')
      el.classList.add('row-unselected')
      const titleSpan = el.querySelector('a span.truncate')
      if (titleSpan) {
        titleSpan.classList.remove('app-accent-on-light', 'font-medium')
        // Check if it's a draft (italic) or published
        if (titleSpan.classList.contains('italic')) {
          titleSpan.classList.add('app-text-muted')
        } else {
          titleSpan.classList.add('app-text-secondary')
        }
      }
    })

    // Add selection to clicked article
    this.element.classList.remove('row-unselected')
    this.element.classList.add('row-selected')
    const titleSpan = this.element.querySelector('a span.truncate')
    if (titleSpan) {
      titleSpan.classList.remove('app-text-secondary', 'app-text-muted')
      titleSpan.classList.add('app-accent-on-light', 'font-medium')
    }
  }
}

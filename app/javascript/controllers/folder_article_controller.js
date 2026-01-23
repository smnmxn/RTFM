import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    // Remove selection from all articles
    document.querySelectorAll('[data-controller="folder-article"]').forEach(el => {
      el.classList.remove('border-indigo-500', 'bg-indigo-50')
      el.classList.add('border-transparent')
      const titleSpan = el.querySelector('a span.truncate')
      if (titleSpan) {
        titleSpan.classList.remove('text-indigo-700', 'font-medium')
        // Check if it's a draft (italic) or published
        if (titleSpan.classList.contains('italic')) {
          titleSpan.classList.add('text-gray-400')
        } else {
          titleSpan.classList.add('text-gray-700')
        }
      }
    })

    // Add selection to clicked article
    this.element.classList.remove('border-transparent')
    this.element.classList.add('border-indigo-500', 'bg-indigo-50')
    const titleSpan = this.element.querySelector('a span.truncate')
    if (titleSpan) {
      titleSpan.classList.remove('text-gray-700', 'text-gray-400')
      titleSpan.classList.add('text-indigo-700', 'font-medium')
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    // Remove selection from all rows
    document.querySelectorAll('[data-controller="inbox-row"] a').forEach(link => {
      link.classList.remove('row-selected')
      link.classList.add('row-unselected')
    })

    // Add selection to clicked row
    const link = this.element.querySelector('a')
    link.classList.remove('row-unselected')
    link.classList.add('row-selected')
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    // Remove selection from all rows
    document.querySelectorAll('[data-controller="inbox-row"] a').forEach(link => {
      link.classList.remove('border-indigo-500', 'bg-indigo-50')
      link.classList.add('border-transparent', 'bg-white')
    })

    // Add selection to clicked row
    const link = this.element.querySelector('a')
    link.classList.remove('border-transparent', 'bg-white')
    link.classList.add('border-indigo-500', 'bg-indigo-50')
  }
}

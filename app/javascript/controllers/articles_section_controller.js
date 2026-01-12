import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    // Remove selection from all section rows
    document.querySelectorAll('[data-controller="articles-section"] button').forEach(btn => {
      btn.classList.remove('bg-white', 'border-indigo-500')
      btn.classList.add('border-transparent')
      // Update text colors
      btn.querySelector('span:first-child')?.classList.remove('text-indigo-700')
      btn.querySelector('span:first-child')?.classList.add('text-gray-700')
      btn.querySelector('span:last-child')?.classList.remove('bg-indigo-100', 'text-indigo-700')
      btn.querySelector('span:last-child')?.classList.add('bg-gray-200', 'text-gray-600')
    })

    // Add selection to clicked row
    const btn = this.element.querySelector('button')
    btn.classList.remove('border-transparent')
    btn.classList.add('bg-white', 'border-indigo-500')
    // Update text colors
    btn.querySelector('span:first-child')?.classList.remove('text-gray-700')
    btn.querySelector('span:first-child')?.classList.add('text-indigo-700')
    btn.querySelector('span:last-child')?.classList.remove('bg-gray-200', 'text-gray-600')
    btn.querySelector('span:last-child')?.classList.add('bg-indigo-100', 'text-indigo-700')
  }
}

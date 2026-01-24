import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["thinking", "content", "text", "cursor", "sources", "rendered"]
  static values = { streamId: String }

  connect() {
    this.started = false
    this.rawText = ""
    this.isProcessing = false

    // Observe the text target for Turbo Stream appends
    this.observer = new MutationObserver(this.handleMutation.bind(this))
    this.observer.observe(this.textTarget, {
      childList: true,
      subtree: false
    })
  }

  handleMutation(mutations) {
    // Prevent re-entry
    if (this.isProcessing) return
    this.isProcessing = true

    try {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE && node.tagName === 'SPAN') {
            // Check if this is the "done" signal
            if (node.dataset.streamingDone === 'true') {
              this.handleComplete()
              return
            }

            // Get text from the span
            const text = node.textContent || ""
            if (text) {
              this.handleChunk(text)
            }
          }
        }
      }
    } finally {
      this.isProcessing = false
    }
  }

  handleChunk(text) {
    // On first chunk, transition from thinking to content
    if (!this.started) {
      this.started = true
      this.thinkingTarget.classList.add("hidden")
      this.contentTarget.classList.remove("hidden")
    }

    // Accumulate raw text
    this.rawText += text

    // Update the rendered view with debouncing
    this.scheduleRender()
  }

  scheduleRender() {
    if (this.renderTimeout) {
      clearTimeout(this.renderTimeout)
    }
    this.renderTimeout = setTimeout(() => this.render(), 50)
  }

  render() {
    // Render markdown to the rendered target (separate from where Turbo appends)
    if (this.hasRenderedTarget) {
      this.renderedTarget.innerHTML = this.parseMarkdown(this.rawText)
      this.addImageErrorHandlers()
    }
  }

  addImageErrorHandlers() {
    this.renderedTarget.querySelectorAll('img').forEach(img => {
      if (!img.dataset.errorHandled) {
        img.dataset.errorHandled = 'true'
        img.addEventListener('error', () => {
          img.style.display = 'none'
        })
      }
    })
  }

  handleComplete() {
    // Clear any pending render
    if (this.renderTimeout) {
      clearTimeout(this.renderTimeout)
    }

    // Final render
    if (this.hasRenderedTarget) {
      this.renderedTarget.innerHTML = this.parseMarkdown(this.rawText)
    }

    // Hide the cursor
    if (this.hasCursorTarget) {
      this.cursorTarget.classList.add("hidden")
    }

    // Show sources (Turbo Stream will have already replaced the sources element)
    if (this.hasSourcesTarget) {
      this.sourcesTarget.classList.remove("hidden")
    }
  }

  parseMarkdown(text) {
    if (!text) return ''

    // Extract images and links BEFORE escaping to preserve URLs
    const images = []
    const links = []

    // Extract images first: ![alt](url)
    let processed = text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (match, alt, url) => {
      const placeholder = `__IMG_${images.length}__`
      images.push({ alt, url })
      return placeholder
    })

    // Extract links: [text](url)
    processed = processed.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (match, linkText, url) => {
      const placeholder = `__LINK_${links.length}__`
      links.push({ text: linkText, url })
      return placeholder
    })

    // Now escape HTML
    let html = this.escapeHtml(processed)

    // Restore images
    images.forEach((img, i) => {
      const escapedAlt = this.escapeHtml(img.alt)
      html = html.replace(
        `__IMG_${i}__`,
        `<img src="${img.url}" alt="${escapedAlt}" class="my-4 rounded-lg max-w-full border border-gray-200" loading="lazy" />`
      )
    })

    // Restore links
    links.forEach((link, i) => {
      const escapedText = this.escapeHtml(link.text)
      html = html.replace(
        `__LINK_${i}__`,
        `<a href="${link.url}" class="text-brand hover:underline">${escapedText}</a>`
      )
    })

    // Bold: **text**
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')

    // Inline code: `text`
    html = html.replace(/`([^`]+)`/g,
      '<code class="bg-gray-100 px-1.5 py-0.5 rounded text-sm font-mono">$1</code>')

    // Headings (must be processed before paragraphs/line breaks)
    // h4: ####
    html = html.replace(/^#### (.+)$/gm, '<h4 class="text-base font-semibold text-gray-900 mt-4 mb-2">$1</h4>')
    // h3: ###
    html = html.replace(/^### (.+)$/gm, '<h3 class="text-lg font-semibold text-gray-900 mt-5 mb-2">$1</h3>')
    // h2: ##
    html = html.replace(/^## (.+)$/gm, '<h2 class="text-xl font-semibold text-gray-900 mt-6 mb-3">$1</h2>')
    // h1: #
    html = html.replace(/^# (.+)$/gm, '<h1 class="text-2xl font-bold text-gray-900 mt-6 mb-3">$1</h1>')

    // Paragraphs (double newlines)
    html = html.replace(/\n\n/g, '</p><p class="mt-3">')

    // Line breaks (single newlines)
    html = html.replace(/\n/g, '<br>')

    // Wrap in paragraph
    html = '<p>' + html + '</p>'

    return html
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.renderTimeout) {
      clearTimeout(this.renderTimeout)
    }
  }
}

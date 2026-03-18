import { Controller } from "@hotwired/stimulus"

// Smooth scrolls to an anchor target with eased animation.
// Cancels if the user scrolls manually (wheel, touch, or key).
// Usage: <a href="/#features" data-controller="smooth-scroll" data-action="click->smooth-scroll#scroll">
export default class extends Controller {
  scroll(event) {
    const href = this.element.getAttribute("href")
    if (!href || !href.includes("#")) return

    const hash = href.split("#")[1]
    if (!hash) return

    const hrefPath = href.split("#")[0] || "/"
    const currentPath = window.location.pathname

    // Same page - smooth scroll directly
    if (hrefPath === currentPath || (hrefPath === "/" && currentPath === "/")) {
      event.preventDefault()
      const target = document.getElementById(hash)
      if (target) this.animateToElement(target, hash)
    } else {
      // Different page - navigate without hash, then scroll after load
      event.preventDefault()
      sessionStorage.setItem("smoothScrollTarget", hash)
      window.Turbo ? Turbo.visit(hrefPath) : (window.location.href = hrefPath)
    }
  }

  connect() {
    // Check if we arrived here via a cross-page scroll request
    const hash = sessionStorage.getItem("smoothScrollTarget")
    if (hash) {
      sessionStorage.removeItem("smoothScrollTarget")
      // Wait for the page to render, then scroll
      requestAnimationFrame(() => {
        window.scrollTo(0, 0)
        requestAnimationFrame(() => {
          const target = document.getElementById(hash)
          if (target) {
            setTimeout(() => this.animateToElement(target, hash), 50)
          }
        })
      })
    }
  }

  animateToElement(target, hash) {
    const start = window.scrollY
    const end = target.getBoundingClientRect().top + window.scrollY - 80
    const distance = end - start

    if (Math.abs(distance) < 1) return

    const duration = 800
    const startTime = performance.now()
    let cancelled = false
    let rafId = null

    const cancel = () => {
      cancelled = true
      if (rafId) cancelAnimationFrame(rafId)
      cleanup()
    }

    const cleanup = () => {
      window.removeEventListener("wheel", cancel)
      window.removeEventListener("touchmove", cancel)
      window.removeEventListener("keydown", cancelOnKey)
    }

    const cancelOnKey = (e) => {
      if (["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " "].includes(e.key)) {
        cancel()
      }
    }

    window.addEventListener("wheel", cancel, { passive: true, once: true })
    window.addEventListener("touchmove", cancel, { passive: true, once: true })
    window.addEventListener("keydown", cancelOnKey, { once: true })

    const ease = (t) => 1 - Math.pow(1 - t, 3)

    const step = (now) => {
      if (cancelled) return

      const elapsed = now - startTime
      const progress = Math.min(elapsed / duration, 1)
      window.scrollTo(0, start + distance * ease(progress))

      if (progress < 1) {
        rafId = requestAnimationFrame(step)
      } else {
        cleanup()
      }
    }

    rafId = requestAnimationFrame(step)
    if (hash) history.replaceState(null, "", `#${hash}`)
  }
}

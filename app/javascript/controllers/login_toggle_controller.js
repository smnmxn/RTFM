import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop", "signInForm", "registerForm", "modalTitle", "modalSubtitle", "toggleText", "toggleLink"]

  connect() {
    this.handleEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.handleEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleEscape)
  }

  open(event) {
    event?.preventDefault()
    const mode = event?.params?.mode || "signin"
    this.openModal(mode)
  }

  openModal(mode) {
    if (mode === "register") {
      this.showRegisterForm()
    } else {
      this.showSignInForm()
    }
    this.modalTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close() {
    this.modalTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    document.body.style.overflow = ""
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  showRegister(event) {
    event?.preventDefault()
    this.showRegisterForm()
  }

  showSignIn(event) {
    event?.preventDefault()
    this.showSignInForm()
  }

  showSignInForm() {
    this.signInFormTarget.classList.remove("hidden")
    this.registerFormTarget.classList.add("hidden")
    this.modalTitleTarget.textContent = "Welcome back"
    this.modalSubtitleTarget.textContent = "Sign in to your account"
    this.toggleTextTarget.textContent = "Don\u2019t have an account?"
    this.toggleLinkTarget.textContent = "Sign up"
    this.toggleLinkTarget.dataset.action = "click->login-toggle#showRegister"
  }

  showRegisterForm() {
    this.registerFormTarget.classList.remove("hidden")
    this.signInFormTarget.classList.add("hidden")
    this.modalTitleTarget.textContent = "Create your account"
    this.modalSubtitleTarget.textContent = "Get started with SupportPages"
    this.toggleTextTarget.textContent = "Already have an account?"
    this.toggleLinkTarget.textContent = "Log in"
    this.toggleLinkTarget.dataset.action = "click->login-toggle#showSignIn"
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}

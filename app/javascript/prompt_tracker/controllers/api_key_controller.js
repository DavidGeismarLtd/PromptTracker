import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="prompt-tracker--api-key"
export default class extends Controller {
  static targets = ["key", "toggleIcon", "copyButton"]

  connect() {
    console.log("API Key controller connected!")
    this.isVisible = false
  }

  toggle() {
    console.log("Toggle clicked!")
    this.isVisible = !this.isVisible

    if (this.isVisible) {
      this.keyTarget.type = "text"
      this.toggleIconTarget.classList.remove("bi-eye")
      this.toggleIconTarget.classList.add("bi-eye-slash")
    } else {
      this.keyTarget.type = "password"
      this.toggleIconTarget.classList.remove("bi-eye-slash")
      this.toggleIconTarget.classList.add("bi-eye")
    }
  }

  copy() {
    console.log("Copy clicked!")
    const key = this.keyTarget.value
    navigator.clipboard.writeText(key).then(() => {
      console.log("Copied to clipboard:", key)
      // Show success feedback
      const originalText = this.copyButtonTarget.innerHTML
      this.copyButtonTarget.innerHTML = '<i class="bi bi-check"></i> Copied!'
      this.copyButtonTarget.classList.remove("btn-outline-secondary")
      this.copyButtonTarget.classList.add("btn-success")

      setTimeout(() => {
        this.copyButtonTarget.innerHTML = originalText
        this.copyButtonTarget.classList.remove("btn-success")
        this.copyButtonTarget.classList.add("btn-outline-secondary")
      }, 2000)
    })
  }

  regenerate(event) {
    if (!confirm("Are you sure you want to regenerate the API key? The old key will stop working immediately.")) {
      event.preventDefault()
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// Connects to data-controller="tooltip"
export default class extends Controller {
  connect() {
    // Initialize all tooltips within this controller's scope
    this.initializeTooltips()
  }

  disconnect() {
    // Clean up tooltips when controller disconnects
    this.disposeTooltips()
  }

  initializeTooltips() {
    const tooltipTriggerList = this.element.querySelectorAll('[data-bs-toggle="tooltip"]')
    this.tooltips = Array.from(tooltipTriggerList).map(tooltipTriggerEl => {
      return new bootstrap.Tooltip(tooltipTriggerEl)
    })
  }

  disposeTooltips() {
    if (this.tooltips) {
      this.tooltips.forEach(tooltip => tooltip.dispose())
      this.tooltips = []
    }
  }
}

import { Controller } from "@hotwired/stimulus"

/**
 * Patterns Stimulus Controller
 * Manages adding/removing pattern inputs and syncs them to a hidden JSON field
 */
export default class extends Controller {
  static targets = ["list", "input", "hiddenField", "noMessage"]

  connect() {
    this.updateJson()
  }

  /**
   * Add a new pattern input
   */
  addPattern() {
    this.addPatternWithValueInternal('')
  }

  /**
   * Add a new pattern input with a predefined value (from helper buttons)
   */
  addPatternWithValue(event) {
    const pattern = event.currentTarget.dataset.patternsPatternValue || ''
    this.addPatternWithValueInternal(pattern)
  }

  /**
   * Internal method to add a pattern with an optional value
   */
  addPatternWithValueInternal(patternValue) {
    // Remove "no patterns" message if it exists
    if (this.hasNoMessageTarget) {
      this.noMessageTarget.remove()
    }

    const patternItem = document.createElement('div')
    patternItem.className = 'input-group mb-2 pattern-item'
    patternItem.innerHTML = `
      <span class="input-group-text"><i class="bi bi-regex"></i></span>
      <input type="text"
             class="form-control"
             data-patterns-target="input"
             data-action="input->patterns#updateJson"
             value="${this.escapeHtml(patternValue)}"
             placeholder="e.g., /Hello/ or /\\d{3}-\\d{4}/">
      <button type="button"
              class="btn btn-outline-danger"
              data-action="click->patterns#removePattern">
        <i class="bi bi-trash"></i>
      </button>
    `

    this.listTarget.appendChild(patternItem)

    // Focus on the new input
    const newInput = patternItem.querySelector('input')
    if (newInput) {
      newInput.focus()
      // If there's a value, select it so user can easily modify it
      if (patternValue) {
        newInput.select()
      }
    }

    this.updateJson()
  }

  /**
   * Escape HTML to prevent XSS
   */
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  /**
   * Remove a pattern input
   */
  removePattern(event) {
    const patternItem = event.target.closest('.pattern-item')
    patternItem.remove()
    this.updateJson()

    // Show "no patterns" message if list is empty
    if (this.listTarget.querySelectorAll('.pattern-item').length === 0) {
      this.listTarget.innerHTML = `
        <div class="text-muted text-center py-3" data-patterns-target="noMessage">
          <i class="bi bi-info-circle"></i> No patterns defined. Click "Add Pattern" to add one.
        </div>
      `
    }
  }

  /**
   * Update the hidden JSON field with current patterns
   */
  updateJson() {
    const patterns = []

    this.inputTargets.forEach(input => {
      if (input.value.trim()) {
        patterns.push(input.value.trim())
      }
    })

    this.hiddenFieldTarget.value = JSON.stringify(patterns)
  }
};

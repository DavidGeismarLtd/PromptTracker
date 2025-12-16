import { Controller } from "@hotwired/stimulus"

/**
 * Template Variables Stimulus Controller
 * Manages template variable inputs and syncs them to a hidden JSON field
 */
export default class extends Controller {
  static targets = ["input", "hiddenField"]

  connect() {
    this.updateJson()
  }

  /**
   * Called when any variable input changes
   */
  updateJson() {
    const variables = {}
    
    this.inputTargets.forEach(input => {
      const varName = input.dataset.varName
      const varType = input.dataset.varType
      let value = input.value

      // Convert value based on type
      if (varType === 'number') {
        value = parseFloat(value) || 0
      } else if (varType === 'boolean') {
        value = value === 'true'
      } else if (varType === 'array' || varType === 'object') {
        try {
          value = JSON.parse(value)
        } catch (e) {
          value = varType === 'array' ? [] : {}
        }
      }

      variables[varName] = value
    })

    this.hiddenFieldTarget.value = JSON.stringify(variables)
  }
}
;

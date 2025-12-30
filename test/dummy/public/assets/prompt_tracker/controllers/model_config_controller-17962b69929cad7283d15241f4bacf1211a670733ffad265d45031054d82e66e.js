import { Controller } from "@hotwired/stimulus"

/**
 * Model Config Stimulus Controller
 * Manages model provider selection and syncs configuration to a hidden JSON field
 */
export default class extends Controller {
  static targets = ["provider", "model", "temperature", "maxTokens", "hiddenField", "modelGroup"]

  connect() {
    this.updateJson()
  }

  /**
   * Called when provider selection changes
   */
  providerChanged() {
    const provider = this.providerTarget.value

    // Hide all model groups
    this.modelGroupTargets.forEach(group => {
      group.style.display = 'none'
    })

    // Show the selected provider's model group
    const targetGroup = this.modelGroupTargets.find(
      group => group.id === `${provider}_models`
    )
    
    if (targetGroup) {
      targetGroup.style.display = 'block'
      
      // Select first option in the group
      const firstOption = targetGroup.querySelector('option')
      if (firstOption) {
        firstOption.selected = true
      }
    }

    this.updateJson()
  }

  /**
   * Update the hidden JSON field with current model configuration
   */
  updateJson() {
    const config = {
      provider: this.providerTarget.value,
      model: this.modelTarget.value,
      temperature: parseFloat(this.temperatureTarget.value)
    }

    const maxTokens = this.maxTokensTarget.value
    if (maxTokens) {
      config.max_tokens = parseInt(maxTokens)
    }

    this.hiddenFieldTarget.value = JSON.stringify(config)
  }
}
;

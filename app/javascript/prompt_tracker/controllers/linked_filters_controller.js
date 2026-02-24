import { Controller } from "@hotwired/stimulus"

/**
 * Linked Filters Controller
 *
 * Links provider and model dropdowns so that when a provider is selected,
 * the model dropdown only shows models for that provider.
 */
export default class extends Controller {
  static targets = ["provider", "model", "modelsData"]

  connect() {
    this.modelsByProvider = this.loadModelsData()
    this.allModels = this.collectAllModels()
  }

  loadModelsData() {
    if (!this.hasModelsDataTarget) return {}
    try {
      return JSON.parse(this.modelsDataTarget.textContent)
    } catch {
      return {}
    }
  }

  collectAllModels() {
    // Collect all unique models from all providers
    const allModels = new Set()
    Object.values(this.modelsByProvider).forEach(models => {
      models.forEach(model => allModels.add(model))
    })
    return Array.from(allModels).sort()
  }

  providerChanged() {
    const selectedProvider = this.providerTarget.value
    const modelSelect = this.modelTarget
    const currentModel = modelSelect.value

    // Determine which models to show
    const modelsToShow = selectedProvider
      ? (this.modelsByProvider[selectedProvider] || [])
      : this.allModels

    // Rebuild model options
    modelSelect.innerHTML = '<option value="">All Models</option>'
    modelsToShow.forEach(model => {
      const option = document.createElement('option')
      option.value = model
      option.textContent = model
      modelSelect.appendChild(option)
    })

    // Try to keep the current model selected if it's still available
    if (modelsToShow.includes(currentModel)) {
      modelSelect.value = currentModel
    } else {
      modelSelect.value = ""
    }

    // Submit the form
    this.providerTarget.form.submit()
  }
}


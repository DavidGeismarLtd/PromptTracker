import { Controller } from "@hotwired/stimulus"

/**
 * Playground Sync Visibility Controller
 *
 * Manages the visibility of sync buttons (Push/Pull) in the playground based on
 * API capabilities (checks if the current provider/API supports :remote_entity_linked feature).
 *
 * The sync buttons should only be visible when the current provider/API combination
 * supports the :remote_entity_linked feature (e.g., OpenAI Assistants API).
 *
 * This controller uses the capabilities data from the playground-ui controller outlet
 * to determine visibility, avoiding hardcoded provider/API checks.
 *
 * @example
 * <div data-controller="playground-sync-visibility"
 *      data-playground-sync-visibility-playground-ui-outlet="#playground-container">
 *   <div data-playground-sync-visibility-target="syncButtons">
 *     <!-- sync buttons here -->
 *   </div>
 * </div>
 */
export default class extends Controller {
  static targets = ["syncButtons"]

  static outlets = ["playground-ui"]

  connect() {
    console.log('[PlaygroundSyncVisibilityController] Connected')
    // Don't update visibility on connect - let server-side rendering handle initial state
    // Only update when provider/API actually changes via events
  }

  /**
   * Called when the playground-ui outlet connects
   * This ensures we have access to the UI controller for capability checks
   */
  playgroundUiOutletConnected() {
    console.log('[PlaygroundSyncVisibilityController] playground-ui outlet connected')
    // Don't update visibility here either - only update on actual changes
  }

  disconnect() {
    console.log('[PlaygroundSyncVisibilityController] Disconnected')
  }

  /**
   * Update the visibility of sync buttons based on current provider and API
   * This method is called:
   * - When provider changes (via custom event)
   * - When API changes (via custom event)
   */
  updateVisibility() {
    if (!this.hasSyncButtonsTarget) {
      return
    }

    const shouldShow = this.shouldShowSyncButtons()

    if (shouldShow) {
      this.syncButtonsTarget.style.display = ''
    } else {
      this.syncButtonsTarget.style.display = 'none'
    }
  }

  /**
   * Determine if sync buttons should be shown based on API capabilities
   * @returns {boolean} True if buttons should be visible
   */
  shouldShowSyncButtons() {
    // Check if we have the playground-ui outlet
    if (!this.hasPlaygroundUiOutlet) {
      return false
    }

    const uiController = this.playgroundUiOutlet

    // Get current provider and API from the UI controller
    const provider = this.getCurrentProvider(uiController)
    const api = this.getCurrentApi(uiController)

    if (!provider || !api) {
      return false
    }

    // Check capabilities from the data already available in playground-ui controller
    const capabilities = uiController.getCapabilities(provider, api)
    const features = capabilities.features || []
    const supportsRemoteEntity = features.includes('remote_entity_linked')

    return supportsRemoteEntity
  }

  /**
   * Get the current provider from the UI controller
   * @param {Controller} uiController - The playground-ui controller
   * @returns {string} The current provider
   */
  getCurrentProvider(uiController) {
    if (!uiController.hasModelProviderTarget) {
      return null
    }
    const value = uiController.modelProviderTarget.value
    return value || null
  }

  /**
   * Get the current API from the UI controller
   * @param {Controller} uiController - The playground-ui controller
   * @returns {string} The current API
   */
  getCurrentApi(uiController) {
    if (!uiController.hasModelApiTarget) {
      return null
    }
    return uiController.modelApiTarget.value
  }

  /**
   * Handle provider change event
   * This is called via a custom event dispatched by playground-ui controller
   */
  onProviderChange(event) {
    // Use the provider/API from the event detail instead of reading from dropdowns
    const { provider, api } = event.detail
    this.updateVisibilityForProviderApi(provider, api)
  }

  /**
   * Handle API change event
   * This is called via a custom event dispatched by playground-ui controller
   */
  onApiChange(event) {

    // Use the provider/API from the event detail instead of reading from dropdowns
    const { provider, api } = event.detail
    this.updateVisibilityForProviderApi(provider, api)
  }

  /**
   * Update visibility for a specific provider/API combination
   * @param {string} provider - Provider name
   * @param {string} api - API name
   */
  updateVisibilityForProviderApi(provider, api) {
    if (!this.hasSyncButtonsTarget) {
      return
    }

    if (!provider || !api) {
      return
    }

    // Check if we have the playground-ui outlet for capabilities
    if (!this.hasPlaygroundUiOutlet) {
      return
    }

    const capabilities = this.playgroundUiOutlet.getCapabilities(provider, api)
    const features = capabilities.features || []
    const shouldShow = features.includes('remote_entity_linked')

    if (shouldShow) {
      this.syncButtonsTarget.style.display = ''
    } else {
      this.syncButtonsTarget.style.display = 'none'
    }
  }
}

import { Controller } from "@hotwired/stimulus"

/**
 * Evaluator Form Stimulus Controller
 * Handles dynamic loading of evaluator forms using Turbo Frames
 */
export default class extends Controller {
  static targets = ["select"]
  static values = {
    responseId: Number
  }

  /**
   * Load the appropriate form template when evaluator is selected
   */
  loadForm(event) {
    const selectedOption = this.selectTarget.options[this.selectTarget.selectedIndex]
    const evaluatorKey = selectedOption.value
    const evaluatorType = selectedOption.dataset.evaluatorType

    const frame = document.getElementById("evaluator_form_container")
    if (!frame) return

    if (!evaluatorKey) {
      // Reset to empty state
      frame.innerHTML = `
        <div class="text-center py-4 text-muted">
          <i class="bi bi-arrow-up"></i>
          <p>Select an evaluator above to begin</p>
        </div>
      `
      return
    }

    // Build the URL for the form template
    const url = this.buildFormUrl(evaluatorKey, evaluatorType)

    // Set the frame's src attribute to trigger Turbo Frame navigation
    frame.src = url
  }

  /**
   * Build the URL for fetching the form template
   */
  buildFormUrl(evaluatorKey, evaluatorType) {
    const params = new URLSearchParams({
      evaluator_key: evaluatorKey,
      evaluator_type: evaluatorType,
      llm_response_id: this.responseIdValue
    })

    return `/prompt_tracker/evaluations/form_template?${params.toString()}`
  }
}

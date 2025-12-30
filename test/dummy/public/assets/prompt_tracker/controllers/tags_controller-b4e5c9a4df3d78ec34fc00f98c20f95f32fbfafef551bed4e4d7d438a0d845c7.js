import { Controller } from "@hotwired/stimulus"

/**
 * Tags Stimulus Controller
 * Manages adding/removing tag inputs and syncs them to a hidden JSON field
 */
export default class extends Controller {
  static targets = ["list", "input", "hiddenField", "noMessage"]

  connect() {
    this.updateJson()
  }

  /**
   * Add a new tag input
   */
  addTag() {
    // Remove "no tags" message if it exists
    if (this.hasNoMessageTarget) {
      this.noMessageTarget.remove()
    }

    const tagItem = document.createElement('div')
    tagItem.className = 'input-group mb-2 tag-item'
    tagItem.innerHTML = `
      <span class="input-group-text"><i class="bi bi-tag"></i></span>
      <input type="text" 
             class="form-control" 
             data-tags-target="input"
             data-action="input->tags#updateJson"
             placeholder="e.g., smoke, critical, regression">
      <button type="button" 
              class="btn btn-outline-danger"
              data-action="click->tags#removeTag">
        <i class="bi bi-trash"></i>
      </button>
    `

    this.listTarget.appendChild(tagItem)
    this.updateJson()
  }

  /**
   * Remove a tag input
   */
  removeTag(event) {
    const tagItem = event.target.closest('.tag-item')
    tagItem.remove()
    this.updateJson()

    // Show "no tags" message if list is empty
    if (this.listTarget.querySelectorAll('.tag-item').length === 0) {
      this.listTarget.innerHTML = `
        <div class="text-muted text-center py-3" data-tags-target="noMessage">
          <i class="bi bi-info-circle"></i> No tags defined. Click "Add Tag" to add one.
        </div>
      `
    }
  }

  /**
   * Update the hidden JSON field with current tags
   */
  updateJson() {
    const tags = []
    
    this.inputTargets.forEach(input => {
      if (input.value.trim()) {
        tags.push(input.value.trim())
      }
    })

    this.hiddenFieldTarget.value = JSON.stringify(tags)
  }
}
;

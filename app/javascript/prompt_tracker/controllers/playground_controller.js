import { Controller } from "@hotwired/stimulus"
import { Modal, Collapse } from "bootstrap"

/**
 * PromptPlayground Stimulus Controller
 * Interactive prompt template editor with live preview
 */
export default class extends Controller {
  static targets = [
    "templateEditor",
    "variablesContainer",
    "previewContainer",
    "previewError",
    "engineBadge",
    "refreshBtn",
    "saveDraftBtn",
    "saveUpdateBtn",
    "saveNewVersionBtn",
    "alertContainer",
    "alertMessage",
    "promptNameInput",
    "charCount",
    "previewStatus"
    "modelProvider",
    "modelName",
    "modelTemperature",
    "modelMaxTokens",
    "modelTopP",
    "modelFrequencyPenalty",
    "modelPresencePenalty",
    "temperatureBadge"
  ]

  static values = {
    promptId: Number,
    versionId: Number,
    versionHasResponses: Boolean,
    previewUrl: String,
    saveUrl: String,
    isStandalone: Boolean
  }

  connect() {
    this.debounceTimer = null
    this.debounceDelay = 500 // ms

    this.attachEventListeners()
    this.updatePreview() // Initial preview
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  attachEventListeners() {
    // Tab key in template editor (insert 2 spaces)
    this.templateEditorTarget.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        e.preventDefault()
        const start = this.templateEditorTarget.selectionStart
        const end = this.templateEditorTarget.selectionEnd
        const value = this.templateEditorTarget.value
        this.templateEditorTarget.value = value.substring(0, start) + '  ' + value.substring(end)
        this.templateEditorTarget.selectionStart = this.templateEditorTarget.selectionEnd = start + 2
        this.templateEditorTarget.dispatchEvent(new Event('input'))
      }
    })

    // Example template buttons
    document.querySelectorAll('.use-example-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const template = btn.dataset.template
        this.templateEditorTarget.value = template
        this.templateEditorTarget.dispatchEvent(new Event('input'))
        // Close modal
        const modal = Modal.getInstance(document.getElementById('templateExamplesModal'))
        if (modal) modal.hide()
        this.showAlert('Template loaded! Customize it as needed.', 'success')
      })
    })

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      this.handleKeyboardShortcuts(e)
    })

    // Initial character count
    this.updateCharCount()
  }

  // Action: Template editor input
  onTemplateInput() {
    this.debouncedUpdatePreview()
    this.updateVariableInputs()
    this.updateCharCount()
  }

  // Action: Variable input
  onVariableInput(event) {
    if (event.target.classList.contains('variable-input')) {
      this.debouncedUpdatePreview()
    }
  }

  // Action: Model config change
  onModelConfigChange() {
    // Update temperature badge
    if (this.hasTemperatureBadgeTarget && this.hasModelTemperatureTarget) {
      this.temperatureBadgeTarget.textContent = this.modelTemperatureTarget.value
    }
  }

  // Action: Refresh preview
  refreshPreview() {
    this.updatePreview()
  }

  // Action: Save draft
  saveDraft(event) {
    const saveAction = event?.params?.action || 'new_version'
    this.performSave(saveAction)
  }

  debouncedUpdatePreview() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.updatePreview()
    }, this.debounceDelay)
  }

  async updatePreview() {
    const template = this.templateEditorTarget.value
    const variables = this.collectVariables()

    if (!template.trim()) {
      this.previewContainerTarget.innerHTML = '<p class="text-muted">Enter a template to see preview...</p>'
      this.previewErrorTarget.style.display = 'none'
      return
    }

    // Show loading state
    this.showPreviewLoading(true)

    try {
      const response = await fetch(this.previewUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken(),
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          template: template,
          variables: variables
        })
      })

      if (!response.ok) {
        const text = await response.text()
        console.error('Server error response:', text)
        this.showPreviewError([`Server error (${response.status}): ${response.statusText}`])
        this.showPreviewLoading(false)
        return
      }

      const contentType = response.headers.get('content-type')
      if (!contentType || !contentType.includes('application/json')) {
        const text = await response.text()
        console.error('Non-JSON response:', text)
        this.showPreviewError(['Server returned non-JSON response. Check console for details.'])
        this.showPreviewLoading(false)
        return
      }

      const data = await response.json()

      if (data.success) {
        this.previewContainerTarget.innerHTML = this.escapeHtml(data.rendered)
        this.previewErrorTarget.style.display = 'none'
        this.updateEngineBadge()
        this.updateVariablesFromDetection(data.variables_detected)
      } else {
        this.showPreviewError(data.errors)
      }
    } catch (error) {
      console.error('Preview error:', error)
      this.showPreviewError(['Network error: ' + error.message])
    } finally {
      this.showPreviewLoading(false)
    }
  }

  updateVariableInputs() {
    const template = this.templateEditorTarget.value
    const variables = this.extractVariables(template)

    // Get current variable values
    const currentValues = this.collectVariables()

    // Rebuild variable inputs
    if (variables.length === 0) {
      this.variablesContainerTarget.innerHTML = '<p class="text-muted">No variables detected. Start typing in the template editor.</p>'
      return
    }

    let html = ''
    variables.forEach(varName => {
      const value = currentValues[varName] || ''
      html += `
        <div class="mb-2">
          <label for="var-${varName}" class="form-label"><code>${varName}</code></label>
          <input
            type="text"
            class="form-control variable-input"
            id="var-${varName}"
            data-variable-name="${varName}"
            value="${this.escapeHtml(value)}"
            placeholder="Enter value for ${varName}"
            data-action="input->playground#onVariableInput"
          >
        </div>
      `
    })

    this.variablesContainerTarget.innerHTML = html
  }

  updateVariablesFromDetection(detectedVars) {
    // This is called after preview to ensure we have all variables
    // Only update if we have new variables
    if (!detectedVars || detectedVars.length === 0) return

    const currentVars = Array.from(this.variablesContainerTarget.querySelectorAll('.variable-input'))
      .map(input => input.dataset.variableName)

    const newVars = detectedVars.filter(v => !currentVars.includes(v))

    if (newVars.length > 0) {
      this.updateVariableInputs()
    }
  }

  extractVariables(template) {
    const variables = new Set()

    // Liquid-style: {{ variable }}
    const simpleMatches = template.matchAll(/\{\{\s*(\w+)\s*\}\}/g)
    for (const match of simpleMatches) {
      variables.add(match[1])
    }

    // Liquid filters: {{ variable | filter }}
    const filterMatches = template.matchAll(/\{\{\s*(\w+)\s*\|/g)
    for (const match of filterMatches) {
      variables.add(match[1])
    }

    // Liquid object notation: {{ object.property }}
    const objectMatches = template.matchAll(/\{\{\s*(\w+)\./g)
    for (const match of objectMatches) {
      variables.add(match[1])
    }

    return Array.from(variables).sort()
  }

  collectVariables() {
    const variables = {}
    const inputs = this.variablesContainerTarget.querySelectorAll('.variable-input')

    inputs.forEach(input => {
      const name = input.dataset.variableName
      const value = input.value
      if (name) {
        variables[name] = value
      }
    })

    return variables
  }

  updateEngineBadge() {
    this.engineBadgeTarget.textContent = 'Liquid'
    this.engineBadgeTarget.className = 'badge bg-primary'
  }

  showPreviewError(errors) {
    this.previewErrorTarget.innerHTML = '<strong>Preview Error:</strong><br>' + errors.join('<br>')
    this.previewErrorTarget.style.display = 'block'
    this.previewContainerTarget.innerHTML = '<p class="text-muted">Fix errors to see preview...</p>'
  }

  async performSave(saveAction = 'new_version') {
    const template = this.templateEditorTarget.value

    if (!template.trim()) {
      this.showAlert('Please enter a template before saving.', 'warning')
      return
    }

    // Validate prompt name in standalone mode
    let promptName = null
    if (this.isStandaloneValue) {
      if (!this.hasPromptNameInputTarget || !this.promptNameInputTarget.value.trim()) {
        this.showAlert('Please enter a prompt name.', 'warning')
        if (this.hasPromptNameInputTarget) {
          this.promptNameInputTarget.focus()
        }
        return
      }
      promptName = this.promptNameInputTarget.value.trim()
    }

      model_config: this.getModelConfig(),    const notes = prompt('Add notes for this version (optional):')
    if (notes === null) return // User cancelled

    // Disable all save buttons and show loading state
    const activeButton = saveAction === 'update' ? this.saveUpdateBtnTarget :
                        (this.hasSaveNewVersionBtnTarget ? this.saveNewVersionBtnTarget : this.saveDraftBtnTarget)

    if (activeButton) {
      activeButton.disabled = true
      activeButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Saving...'
    }

    const requestBody = {
      template: template,
      notes: notes,
      save_action: saveAction,
      model_config: this.getModelConfig()
    }

    if (this.isStandaloneValue) {
      requestBody.prompt_name = promptName
    }

    try {
      const response = await fetch(this.saveUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken()
        },
        body: JSON.stringify(requestBody)
      })

      const data = await response.json()

      if (data.success) {
        if (this.isStandaloneValue) {
          this.showAlert(`Prompt "${promptName}" created successfully!`, 'success')
        } else if (data.action === 'updated') {
          this.showAlert(`Version ${data.version_number} updated successfully!`, 'success')
        } else {
          this.showAlert(`Draft version ${data.version_number} created successfully!`, 'success')
        }
        setTimeout(() => {
          window.location.href = data.redirect_url
        }, 1500)
      } else {
        this.showAlert('Error: ' + data.errors.join(', '), 'danger')
        this.resetSaveButtons(saveAction)
      }
    } catch (error) {
      this.showAlert('Network error: ' + error.message, 'danger')
      this.resetSaveButtons(saveAction)
    }
  }

  resetSaveButtons(saveAction) {
    if (this.isStandaloneValue && this.hasSaveDraftBtnTarget) {
      this.saveDraftBtnTarget.disabled = false
      this.saveDraftBtnTarget.innerHTML = '<i class="bi bi-save"></i> Create Prompt'
    } else if (saveAction === 'update' && this.hasSaveUpdateBtnTarget) {
      this.saveUpdateBtnTarget.disabled = false
      this.saveUpdateBtnTarget.innerHTML = '<i class="bi bi-save"></i> Update This Version'
    } else if (this.hasSaveNewVersionBtnTarget) {
      this.saveNewVersionBtnTarget.disabled = false
      this.saveNewVersionBtnTarget.innerHTML = '<i class="bi bi-plus-circle"></i> Save as New Version'
    } else if (this.hasSaveDraftBtnTarget) {
      this.saveDraftBtnTarget.disabled = false
      this.saveDraftBtnTarget.innerHTML = '<i class="bi bi-save"></i> Save as Draft Version'
    }
  }

  showAlert(message, type) {
    this.alertMessageTarget.textContent = message
    this.alertContainerTarget.className = `alert alert-${type} alert-dismissible fade show`
    this.alertContainerTarget.style.display = 'block'

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.alertContainerTarget.classList.remove('show')
    }, 5000)
  }

  getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  updateCharCount() {
    const count = this.templateEditorTarget.value.length
    this.charCountTarget.textContent = `${count} chars`

    // Color code based on length
    if (count > 2000) {
      this.charCountTarget.className = 'badge bg-danger'
    } else if (count > 1000) {
      this.charCountTarget.className = 'badge bg-warning'
    } else {
      this.charCountTarget.className = 'badge bg-info'
    }
  }

  showPreviewLoading(isLoading) {
    if (this.hasPreviewStatusTarget) {
      this.previewStatusTarget.style.display = isLoading ? 'inline-block' : 'none'
    }
  }

  handleKeyboardShortcuts(e) {
    const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0
    const modKey = isMac ? e.metaKey : e.ctrlKey

    // Ctrl/Cmd + Enter: Refresh preview
    if (modKey && e.key === 'Enter') {
      e.preventDefault()
      this.updatePreview()
      this.showAlert('Preview refreshed', 'info')
    }

    // Ctrl/Cmd + S: Save draft
    if (modKey && e.key === 's') {
      e.preventDefault()
      this.performSave()
    }

    // Ctrl/Cmd + /: Toggle syntax help
    if (modKey && e.key === '/') {
      e.preventDefault()
      const syntaxHelp = document.getElementById('liquidHelp')
      if (syntaxHelp) {
        const bsCollapse = new Collapse(syntaxHelp, {
          toggle: true
        })
      }
    }
  }
}

  // Get model configuration from form
  getModelConfig() {
    const config = {}
    
    if (this.hasModelProviderTarget) {
      config.provider = this.modelProviderTarget.value
    }
    
    if (this.hasModelNameTarget && this.modelNameTarget.value) {
      config.model = this.modelNameTarget.value
    }
    
    if (this.hasModelTemperatureTarget) {
      config.temperature = parseFloat(this.modelTemperatureTarget.value)
    }
    
    if (this.hasModelMaxTokensTarget && this.modelMaxTokensTarget.value) {
      config.max_tokens = parseInt(this.modelMaxTokensTarget.value)
    }
    
    if (this.hasModelTopPTarget && this.modelTopPTarget.value) {
      config.top_p = parseFloat(this.modelTopPTarget.value)
    }
    
    if (this.hasModelFrequencyPenaltyTarget && this.modelFrequencyPenaltyTarget.value) {
      config.frequency_penalty = parseFloat(this.modelFrequencyPenaltyTarget.value)
    }
    
    if (this.hasModelPresencePenaltyTarget && this.modelPresencePenaltyTarget.value) {
      config.presence_penalty = parseFloat(this.modelPresencePenaltyTarget.value)
    }
    
    return config
  }

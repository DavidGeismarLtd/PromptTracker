/**
 * PromptPlayground - Interactive prompt template editor with live preview
 */
class PromptPlayground {
  constructor(options) {
    alert("playground")
    this.promptId = options.promptId;
    this.versionId = options.versionId || null;
    this.versionHasResponses = options.versionHasResponses || false;
    this.previewUrl = options.previewUrl;
    this.saveUrl = options.saveUrl;
    this.isStandalone = options.isStandalone || false;
    this.debounceTimer = null;
    this.debounceDelay = 500; // ms

    this.initializeElements();
    this.attachEventListeners();
    this.updatePreview(); // Initial preview
  }

  initializeElements() {
    this.templateEditor = document.getElementById('template-editor');
    this.variablesContainer = document.getElementById('variables-container');
    this.previewContainer = document.getElementById('preview-container');
    this.previewError = document.getElementById('preview-error');
    this.engineBadge = document.getElementById('template-engine-badge');
    this.refreshBtn = document.getElementById('refresh-preview-btn');
    this.saveDraftBtn = document.getElementById('save-draft-btn');
    this.saveUpdateBtn = document.getElementById('save-update-btn');
    this.saveNewVersionBtn = document.getElementById('save-new-version-btn');
    this.alertContainer = document.getElementById('playground-alert');
    this.alertMessage = document.getElementById('playground-alert-message');
    this.promptNameInput = document.getElementById('prompt-name-input');
    this.charCount = document.getElementById('char-count');
    this.previewStatus = document.getElementById('preview-status');
  }

  attachEventListeners() {
    // Template editor - debounced preview update
    this.templateEditor.addEventListener('input', () => {
      this.debouncedUpdatePreview();
      this.updateVariableInputs();
      this.updateCharCount();
    });

    // Variable inputs - debounced preview update
    this.variablesContainer.addEventListener('input', (e) => {
      if (e.target.classList.contains('variable-input')) {
        this.debouncedUpdatePreview();
      }
    });

    // Refresh button
    this.refreshBtn.addEventListener('click', () => {
      this.updatePreview();
    });

    // Save draft button (for standalone or simple save)
    if (this.saveDraftBtn) {
      this.saveDraftBtn.addEventListener('click', () => {
        this.saveDraft('new_version');
      });
    }

    // Save update button (update existing version)
    if (this.saveUpdateBtn) {
      this.saveUpdateBtn.addEventListener('click', () => {
        this.saveDraft('update');
      });
    }

    // Save new version button (create new version)
    if (this.saveNewVersionBtn) {
      this.saveNewVersionBtn.addEventListener('click', () => {
        this.saveDraft('new_version');
      });
    }

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => {
      this.handleKeyboardShortcuts(e);
    });

    // Tab key in template editor (insert 2 spaces)
    this.templateEditor.addEventListener('keydown', (e) => {
      if (e.key === 'Tab') {
        e.preventDefault();
        const start = this.templateEditor.selectionStart;
        const end = this.templateEditor.selectionEnd;
        const value = this.templateEditor.value;
        this.templateEditor.value = value.substring(0, start) + '  ' + value.substring(end);
        this.templateEditor.selectionStart = this.templateEditor.selectionEnd = start + 2;
        this.templateEditor.dispatchEvent(new Event('input'));
      }
    });

    // Example template buttons
    document.querySelectorAll('.use-example-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const template = btn.dataset.template;
        this.templateEditor.value = template;
        this.templateEditor.dispatchEvent(new Event('input'));
        // Close modal
        const modal = bootstrap.Modal.getInstance(document.getElementById('templateExamplesModal'));
        if (modal) modal.hide();
        this.showAlert('Template loaded! Customize it as needed.', 'success');
      });
    });

    // Initial character count
    this.updateCharCount();
  }

  debouncedUpdatePreview() {
    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.updatePreview();
    }, this.debounceDelay);
  }

  async updatePreview() {
    const template = this.templateEditor.value;
    const variables = this.collectVariables();

    if (!template.trim()) {
      this.previewContainer.innerHTML = '<p class="text-muted">Enter a template to see preview...</p>';
      this.previewError.style.display = 'none';
      return;
    }

    // Show loading state
    this.showPreviewLoading(true);

    try {
      console.log('Preview URL:', this.previewUrl);
      console.log('Sending preview request with:', { template, variables });

      const response = await fetch(this.previewUrl, {
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
      });

      console.log('Response status:', response.status);
      console.log('Response headers:', response.headers.get('content-type'));

      if (!response.ok) {
        const text = await response.text();
        console.error('Server error response:', text);
        this.showPreviewError([`Server error (${response.status}): ${response.statusText}`]);
        this.showPreviewLoading(false);
        return;
      }

      const contentType = response.headers.get('content-type');
      if (!contentType || !contentType.includes('application/json')) {
        const text = await response.text();
        console.error('Non-JSON response:', text);
        this.showPreviewError(['Server returned non-JSON response. Check console for details.']);
        this.showPreviewLoading(false);
        return;
      }

      const data = await response.json();
      console.log('Preview response:', data);

      if (data.success) {
        this.previewContainer.innerHTML = this.escapeHtml(data.rendered);
        this.previewError.style.display = 'none';
        this.updateEngineBadge(data.engine);
        this.updateVariablesFromDetection(data.variables_detected);
      } else {
        this.showPreviewError(data.errors);
      }
    } catch (error) {
      console.error('Preview error:', error);
      this.showPreviewError(['Network error: ' + error.message]);
    } finally {
      this.showPreviewLoading(false);
    }
  }

  updateVariableInputs() {
    const template = this.templateEditor.value;
    const variables = this.extractVariables(template);

    // Get current variable values
    const currentValues = this.collectVariables();

    // Rebuild variable inputs
    if (variables.length === 0) {
      this.variablesContainer.innerHTML = '<p class="text-muted">No variables detected. Start typing in the template editor.</p>';
      return;
    }

    let html = '';
    variables.forEach(varName => {
      const value = currentValues[varName] || '';
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
          >
        </div>
      `;
    });

    this.variablesContainer.innerHTML = html;
  }

  updateVariablesFromDetection(detectedVars) {
    // This is called after preview to ensure we have all variables
    // Only update if we have new variables
    if (!detectedVars || detectedVars.length === 0) return;

    const currentVars = Array.from(this.variablesContainer.querySelectorAll('.variable-input'))
      .map(input => input.dataset.variableName);

    const newVars = detectedVars.filter(v => !currentVars.includes(v));

    if (newVars.length > 0) {
      this.updateVariableInputs();
    }
  }

  extractVariables(template) {
    const variables = new Set();

    // Mustache-style: {{variable}}
    const mustacheMatches = template.matchAll(/\{\{\s*(\w+)\s*\}\}/g);
    for (const match of mustacheMatches) {
      variables.add(match[1]);
    }

    // Liquid filters: {{ variable | filter }}
    const filterMatches = template.matchAll(/\{\{\s*(\w+)\s*\|/g);
    for (const match of filterMatches) {
      variables.add(match[1]);
    }

    // Liquid object notation: {{ object.property }}
    const objectMatches = template.matchAll(/\{\{\s*(\w+)\./g);
    for (const match of objectMatches) {
      variables.add(match[1]);
    }

    return Array.from(variables).sort();
  }

  collectVariables() {
    const variables = {};
    const inputs = this.variablesContainer.querySelectorAll('.variable-input');

    inputs.forEach(input => {
      const name = input.dataset.variableName;
      const value = input.value;
      if (name) {
        variables[name] = value;
      }
    });

    return variables;
  }

  updateEngineBadge(engine) {
    if (engine === 'liquid') {
      this.engineBadge.textContent = 'Liquid';
      this.engineBadge.className = 'badge bg-primary';
    } else {
      this.engineBadge.textContent = 'Mustache';
      this.engineBadge.className = 'badge bg-secondary';
    }
  }

  showPreviewError(errors) {
    this.previewError.innerHTML = '<strong>Preview Error:</strong><br>' + errors.join('<br>');
    this.previewError.style.display = 'block';
    this.previewContainer.innerHTML = '<p class="text-muted">Fix errors to see preview...</p>';
  }

  async saveDraft(saveAction = 'new_version') {
    const template = this.templateEditor.value;

    if (!template.trim()) {
      this.showAlert('Please enter a template before saving.', 'warning');
      return;
    }

    // Validate prompt name in standalone mode
    let promptName = null;
    if (this.isStandalone) {
      if (!this.promptNameInput || !this.promptNameInput.value.trim()) {
        this.showAlert('Please enter a prompt name.', 'warning');
        if (this.promptNameInput) {
          this.promptNameInput.focus();
        }
        return;
      }
      promptName = this.promptNameInput.value.trim();
    }

    const notes = prompt('Add notes for this version (optional):');
    if (notes === null) return; // User cancelled

    // Disable all save buttons and show loading state
    const activeButton = saveAction === 'update' ? this.saveUpdateBtn :
                        (this.saveNewVersionBtn || this.saveDraftBtn);

    if (activeButton) {
      activeButton.disabled = true;
      activeButton.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>Saving...';
    }

    const requestBody = {
      template: template,
      notes: notes,
      save_action: saveAction
    };

    if (this.isStandalone) {
      requestBody.prompt_name = promptName;
    }

    try {
      const response = await fetch(this.saveUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCsrfToken()
        },
        body: JSON.stringify(requestBody)
      });

      const data = await response.json();

      if (data.success) {
        if (this.isStandalone) {
          this.showAlert(`Prompt "${promptName}" created successfully!`, 'success');
        } else if (data.action === 'updated') {
          this.showAlert(`Version ${data.version_number} updated successfully!`, 'success');
        } else {
          this.showAlert(`Draft version ${data.version_number} created successfully!`, 'success');
        }
        setTimeout(() => {
          window.location.href = data.redirect_url;
        }, 1500);
      } else {
        this.showAlert('Error: ' + data.errors.join(', '), 'danger');
        this.resetSaveButtons(saveAction);
      }
    } catch (error) {
      this.showAlert('Network error: ' + error.message, 'danger');
      this.resetSaveButtons(saveAction);
    }
  }

  resetSaveButtons(saveAction) {
    if (this.isStandalone && this.saveDraftBtn) {
      this.saveDraftBtn.disabled = false;
      this.saveDraftBtn.innerHTML = '<i class="bi bi-save"></i> Create Prompt';
    } else if (saveAction === 'update' && this.saveUpdateBtn) {
      this.saveUpdateBtn.disabled = false;
      this.saveUpdateBtn.innerHTML = '<i class="bi bi-save"></i> Update This Version';
    } else if (this.saveNewVersionBtn) {
      this.saveNewVersionBtn.disabled = false;
      this.saveNewVersionBtn.innerHTML = '<i class="bi bi-plus-circle"></i> Save as New Version';
    } else if (this.saveDraftBtn) {
      this.saveDraftBtn.disabled = false;
      this.saveDraftBtn.innerHTML = '<i class="bi bi-save"></i> Save as Draft Version';
    }
  }

  showAlert(message, type) {
    this.alertMessage.textContent = message;
    this.alertContainer.className = `alert alert-${type} alert-dismissible fade show`;
    this.alertContainer.style.display = 'block';

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.alertContainer.classList.remove('show');
    }, 5000);
  }

  getCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  updateCharCount() {
    const count = this.templateEditor.value.length;
    this.charCount.textContent = `${count} chars`;

    // Color code based on length
    if (count > 2000) {
      this.charCount.className = 'badge bg-danger';
    } else if (count > 1000) {
      this.charCount.className = 'badge bg-warning';
    } else {
      this.charCount.className = 'badge bg-info';
    }
  }

  showPreviewLoading(isLoading) {
    if (this.previewStatus) {
      this.previewStatus.style.display = isLoading ? 'inline-block' : 'none';
    }
  }

  handleKeyboardShortcuts(e) {
    const isMac = navigator.platform.toUpperCase().indexOf('MAC') >= 0;
    const modKey = isMac ? e.metaKey : e.ctrlKey;

    // Ctrl/Cmd + Enter: Refresh preview
    if (modKey && e.key === 'Enter') {
      e.preventDefault();
      this.updatePreview();
      this.showAlert('Preview refreshed', 'info');
    }

    // Ctrl/Cmd + S: Save draft
    if (modKey && e.key === 's') {
      e.preventDefault();
      this.saveDraft();
    }

    // Ctrl/Cmd + /: Toggle syntax help
    if (modKey && e.key === '/') {
      e.preventDefault();
      const syntaxHelp = document.getElementById('liquidHelp');
      if (syntaxHelp) {
        const bsCollapse = new bootstrap.Collapse(syntaxHelp, {
          toggle: true
        });
      }
    }
  }
}

// Make it globally available
window.PromptPlayground = PromptPlayground;

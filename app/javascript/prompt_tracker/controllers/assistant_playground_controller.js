import { Controller } from "@hotwired/stimulus"
import { Toast, Modal } from "bootstrap"

// Connects to data-controller="assistant-playground"
export default class extends Controller {
  static targets = [
    "messagesContainer",
    "messageInput",
    "sendButton",
    "threadId",
    "newThreadButton",
    "name",
    "description",
    "instructions",
    "charCount",
    "model",
    "toolCheckbox",
    "responseFormat",
    "temperature",
    "temperatureValue",
    "topP",
    "topPValue",
    "saveButton",
    "saveButtonText",
    "saveStatus",
    "toast",
    "toastBody",
    // Function management targets (only for elements that stay in controller scope)
    "functionsSection",
    "functionList"
    // Note: Modal elements are accessed via getElementById because modal-fix moves them to body
  ]

  static values = {
    assistantId: String,
    isNew: Boolean,
    createUrl: String,
    updateUrl: String,
    sendMessageUrl: String,
    createThreadUrl: String,
    loadMessagesUrl: String
  }

  connect() {
    console.log("Assistant Playground controller connected")

    // Initialize character counter
    this.updateCharCount()

    // Setup auto-save debouncing
    this.saveTimeout = null
    this.setupAutoSave()

    // Load existing thread messages if not new
    if (!this.isNewValue && this.hasThreadIdTarget) {
      this.loadMessages()
    }

    // Setup keyboard shortcuts
    this.setupKeyboardShortcuts()

    // Initialize functions from existing function items in the DOM
    this.initializeFunctions()

    // Setup modal event listeners (Bootstrap moves modals to body, outside controller scope)
    this.setupModalEventListeners()
  }

  disconnect() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
    // Clean up modal event listeners
    this.cleanupModalEventListeners()
  }

  setupModalEventListeners() {
    // Bind the handler so we can remove it later
    this.boundSaveFunctionHandler = this.saveFunction.bind(this)

    // Listen for clicks on the save function button (using event delegation on document)
    document.addEventListener("click", this.handleModalButtonClick.bind(this))
  }

  cleanupModalEventListeners() {
    document.removeEventListener("click", this.handleModalButtonClick.bind(this))
  }

  handleModalButtonClick(event) {
    // Check if the clicked element is the save function button
    const saveButton = event.target.closest('[data-action*="saveFunction"]')
    if (saveButton) {
      event.preventDefault()
      this.saveFunction()
    }
  }

  // ========================================
  // Thread Management
  // ========================================

  async createNewThread() {
    if (this.isNewValue) {
      this.showError("Please save the assistant first")
      return
    }

    try {
      const response = await fetch(this.createThreadUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        }
      })

      const data = await response.json()

      if (data.success) {
        this.currentThreadId = data.thread_id
        this.threadIdTarget.textContent = `Thread: ${data.thread_id.substring(0, 8)}...`
        this.clearMessages()
        this.showSuccess("New thread created")
      } else {
        this.showError(data.error || "Failed to create thread")
      }
    } catch (error) {
      console.error("Error creating thread:", error)
      this.showError("Network error creating thread")
    }
  }

  async loadMessages() {
    if (!this.currentThreadId) return

    try {
      const url = `${this.loadMessagesUrlValue}?thread_id=${this.currentThreadId}`
      const response = await fetch(url, {
        headers: {
          "X-CSRF-Token": this.getCsrfToken()
        }
      })

      const data = await response.json()

      if (data.success && data.messages.length > 0) {
        this.clearMessages()
        data.messages.forEach(msg => {
          this.addMessage(msg.role, msg.content, msg.created_at)
        })
      }
    } catch (error) {
      console.error("Error loading messages:", error)
    }
  }

  // ========================================
  // Message Handling
  // ========================================

  async sendMessage(event) {
    event.preventDefault()

    if (this.isNewValue) {
      this.showError("Please save the assistant first")
      return
    }

    const content = this.messageInputTarget.value.trim()
    if (!content) return

    // Disable input
    this.messageInputTarget.disabled = true
    this.sendButtonTarget.disabled = true

    // Add user message to UI
    this.addMessage("user", content)
    this.messageInputTarget.value = ""

    // Show typing indicator
    this.showTypingIndicator()

    try {
      const response = await fetch(this.sendMessageUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        },
        body: JSON.stringify({
          assistant_id: this.assistantIdValue,
          thread_id: this.currentThreadId,
          content: content
        })
      })

      const data = await response.json()

      this.hideTypingIndicator()

      if (data.success) {
        // Update thread ID if it was auto-created
        if (data.thread_id && !this.currentThreadId) {
          this.currentThreadId = data.thread_id
          this.threadIdTarget.textContent = `Thread: ${data.thread_id.substring(0, 8)}...`
        }

        // Add assistant message
        this.addMessage("assistant", data.message.content, data.message.created_at)

        // Show usage info if available
        if (data.usage) {
          console.log("Token usage:", data.usage)
        }
      } else {
        this.showError(data.error || "Failed to send message")
      }
    } catch (error) {
      console.error("Error sending message:", error)
      this.hideTypingIndicator()
      this.showError("Network error sending message")
    } finally {
      // Re-enable input
      this.messageInputTarget.disabled = false
      this.sendButtonTarget.disabled = false
      this.messageInputTarget.focus()
    }
  }

  addMessage(role, content, createdAt = null) {
    const messageDiv = document.createElement("div")
    messageDiv.className = `message ${role}-message fade-in`

    const avatar = document.createElement("div")
    avatar.className = "message-avatar"
    avatar.innerHTML = role === "user" ? '<i class="bi bi-person"></i>' : '<i class="bi bi-robot"></i>'

    const contentDiv = document.createElement("div")
    contentDiv.className = "message-content"

    const textDiv = document.createElement("div")
    textDiv.className = "message-text"
    textDiv.textContent = content

    const metaDiv = document.createElement("div")
    metaDiv.className = "message-meta"

    const timeSpan = document.createElement("small")
    timeSpan.className = "text-muted"
    timeSpan.textContent = createdAt ? new Date(createdAt).toLocaleTimeString() : new Date().toLocaleTimeString()

    metaDiv.appendChild(timeSpan)
    contentDiv.appendChild(textDiv)
    contentDiv.appendChild(metaDiv)

    messageDiv.appendChild(avatar)
    messageDiv.appendChild(contentDiv)

    // Remove empty state message if present
    const emptyState = this.messagesContainerTarget.querySelector(".text-center.text-muted")
    if (emptyState) {
      emptyState.remove()
    }

    this.messagesContainerTarget.appendChild(messageDiv)
    this.scrollToBottom()
  }

  showTypingIndicator() {
    const indicator = this.messagesContainerTarget.querySelector(".loading")
    if (indicator) {
      // Move indicator to the end of the messages container
      this.messagesContainerTarget.appendChild(indicator)
      indicator.style.display = "flex"
      this.scrollToBottom()
    }
  }

  hideTypingIndicator() {
    const indicator = this.messagesContainerTarget.querySelector(".loading")
    if (indicator) {
      indicator.style.display = "none"
    }
  }

  clearMessages() {
    this.messagesContainerTarget.innerHTML = `
      <div class="text-center text-muted py-5">
        <i class="bi bi-chat-left-text" style="font-size: 3rem;"></i>
        <p class="mt-3">Start a conversation to test your assistant</p>
      </div>
      <div class="message assistant-message loading" style="display: none;">
        <div class="message-avatar">
          <i class="bi bi-robot"></i>
        </div>
        <div class="message-content">
          <div class="typing-indicator">
            <span></span><span></span><span></span>
          </div>
        </div>
      </div>
    `
  }

  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  // ========================================
  // Assistant Configuration
  // ========================================

  async saveAssistant() {
    const assistantData = this.getAssistantData()

    // Validate required fields
    if (!assistantData.name) {
      this.showError("Name is required")
      return
    }

    // Show saving state
    this.setSaveStatus("saving", "Saving...")
    this.saveButtonTarget.classList.add("btn-loading")
    this.saveButtonTarget.disabled = true

    try {
      const url = this.isNewValue ? this.createUrlValue : this.updateUrlValue
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCsrfToken()
        },
        body: JSON.stringify({ assistant: assistantData })
      })

      const data = await response.json()

      if (data.success) {
        this.setSaveStatus("saved", `Saved at ${data.last_saved_at || new Date().toLocaleTimeString()}`)

        // If this was a new assistant, redirect to edit mode
        if (this.isNewValue && data.redirect_url) {
          window.location.href = data.redirect_url
        } else {
          // Update assistant ID if needed
          if (data.assistant_id) {
            this.assistantIdValue = data.assistant_id
          }
          this.showSuccess("Assistant saved successfully")
        }
      } else {
        this.setSaveStatus("error", "Save failed")
        this.showError(data.error || "Failed to save assistant")
      }
    } catch (error) {
      console.error("Error saving assistant:", error)
      this.setSaveStatus("error", "Save failed")
      this.showError("Network error saving assistant")
    } finally {
      this.saveButtonTarget.classList.remove("btn-loading")
      this.saveButtonTarget.disabled = false
    }
  }

  getAssistantData() {
    const tools = []
    this.toolCheckboxTargets.forEach(checkbox => {
      if (checkbox.checked) {
        tools.push(checkbox.value)
      }
    })

    return {
      name: this.nameTarget.value,
      description: this.descriptionTarget.value,
      instructions: this.instructionsTarget.value,
      model: this.modelTarget.value,
      tools: tools,
      functions: this.functions || [],
      temperature: parseFloat(this.temperatureTarget.value),
      top_p: parseFloat(this.topPTarget.value),
      response_format: this.responseFormatTarget.value
    }
  }

  setupAutoSave() {
    // Auto-save on configuration changes (debounced)
    const inputs = [
      this.nameTarget,
      this.descriptionTarget,
      this.instructionsTarget,
      this.modelTarget,
      this.responseFormatTarget,
      this.temperatureTarget,
      this.topPTarget
    ]

    inputs.forEach(input => {
      input.addEventListener("input", () => {
        if (!this.isNewValue) {
          this.debouncedSave()
        }
      })
    })

    this.toolCheckboxTargets.forEach(checkbox => {
      checkbox.addEventListener("change", () => {
        if (!this.isNewValue) {
          this.debouncedSave()
        }
      })
    })

    // Update range value displays
    this.temperatureTarget.addEventListener("input", () => {
      this.temperatureValueTarget.textContent = this.temperatureTarget.value
    })

    this.topPTarget.addEventListener("input", () => {
      this.topPValueTarget.textContent = this.topPTarget.value
    })

    // Update character count
    this.instructionsTarget.addEventListener("input", () => {
      this.updateCharCount()
    })
  }

  debouncedSave() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }

    this.setSaveStatus("saving", "Saving...")

    this.saveTimeout = setTimeout(() => {
      this.saveAssistant()
    }, 3000) // 3 second debounce
  }

  updateCharCount() {
    if (this.hasInstructionsTarget && this.hasCharCountTarget) {
      this.charCountTarget.textContent = this.instructionsTarget.value.length
    }
  }

  // ========================================
  // UI Helpers
  // ========================================

  setSaveStatus(status, message) {
    if (!this.hasSaveStatusTarget) return

    this.saveStatusTarget.className = `text-muted small text-center save-status-${status}`
    this.saveStatusTarget.innerHTML = `<i class="bi bi-${this.getStatusIcon(status)}"></i> ${message}`
  }

  getStatusIcon(status) {
    const icons = {
      saving: "clock",
      saved: "check-circle",
      error: "exclamation-circle"
    }
    return icons[status] || "clock"
  }

  showSuccess(message) {
    this.showToast(message, "success")
  }

  showError(message) {
    this.showToast(message, "error")
  }

  showToast(message, type = "success") {
    if (!this.hasToastTarget || !this.hasToastBodyTarget) {
      console.log(`${type}:`, message)
      return
    }

    // Set toast styling based on type
    const bgClass = type === "success" ? "bg-success" : "bg-danger"
    this.toastTarget.className = `toast align-items-center text-white ${bgClass} border-0`

    // Set icon based on type
    const icon = type === "success" ? "check-circle-fill" : "exclamation-triangle-fill"
    this.toastBodyTarget.innerHTML = `<i class="bi bi-${icon} me-2"></i>${message}`

    // Show the toast using Bootstrap's Toast API
    const bsToast = new Toast(this.toastTarget, {
      autohide: true,
      delay: 3000
    })
    bsToast.show()
  }

  setupKeyboardShortcuts() {
    this.messageInputTarget.addEventListener("keydown", (e) => {
      // Submit on Enter (without Shift)
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.sendMessage(e)
      }
    })
  }

  getCsrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  // ========================================
  // Function Management
  // ========================================

  initializeFunctions() {
    // Parse existing functions from the function list DOM elements
    this.functions = []

    if (!this.hasFunctionListTarget) return

    const functionItems = this.functionListTarget.querySelectorAll(".function-item")
    functionItems.forEach((item) => {
      // We need to store the full function data as data attributes
      const dataAttr = item.getAttribute("data-function-data")
      if (dataAttr) {
        try {
          this.functions.push(JSON.parse(dataAttr))
        } catch (e) {
          console.error("Failed to parse function data:", e)
        }
      }
    })

    console.log(`Initialized ${this.functions.length} functions`)
  }

  // Helper to get modal elements (they are moved to body by modal-fix controller)
  getModalElement(id) {
    return document.getElementById(id)
  }

  addFunction() {
    // Reset the modal for adding a new function
    const editIndex = this.getModalElement("functionEditIndex")
    const modalTitle = this.getModalElement("functionModalTitle")
    const saveButtonText = this.getModalElement("functionSaveButtonText")
    const nameInput = this.getModalElement("functionName")
    const descriptionInput = this.getModalElement("functionDescription")
    const parametersInput = this.getModalElement("functionParameters")
    const strictCheckbox = this.getModalElement("functionStrict")

    if (editIndex) editIndex.value = "-1"
    if (modalTitle) modalTitle.textContent = "Add Function"
    if (saveButtonText) saveButtonText.textContent = "Add Function"
    if (nameInput) nameInput.value = ""
    if (descriptionInput) descriptionInput.value = ""
    if (parametersInput) {
      parametersInput.value = JSON.stringify({
        type: "object",
        properties: {},
        required: []
      }, null, 2)
      parametersInput.classList.remove("is-invalid")
    }
    if (strictCheckbox) strictCheckbox.checked = false

    this.showFunctionModal()
  }

  editFunction(event) {
    const index = parseInt(event.currentTarget.dataset.functionIndex, 10)
    if (index < 0 || index >= this.functions.length) {
      this.showError("Function not found")
      return
    }

    const func = this.functions[index]

    // Get modal elements
    const editIndexInput = this.getModalElement("functionEditIndex")
    const modalTitle = this.getModalElement("functionModalTitle")
    const saveButtonText = this.getModalElement("functionSaveButtonText")
    const nameInput = this.getModalElement("functionName")
    const descriptionInput = this.getModalElement("functionDescription")
    const parametersInput = this.getModalElement("functionParameters")
    const strictCheckbox = this.getModalElement("functionStrict")

    // Populate the modal with existing function data
    if (editIndexInput) editIndexInput.value = index.toString()
    if (modalTitle) modalTitle.textContent = "Edit Function"
    if (saveButtonText) saveButtonText.textContent = "Update Function"
    if (nameInput) nameInput.value = func.name || ""
    if (descriptionInput) descriptionInput.value = func.description || ""
    if (parametersInput) {
      parametersInput.value = JSON.stringify(func.parameters || {}, null, 2)
      parametersInput.classList.remove("is-invalid")
    }
    if (strictCheckbox) strictCheckbox.checked = func.strict || false

    this.showFunctionModal()
  }

  deleteFunction(event) {
    const index = parseInt(event.currentTarget.dataset.functionIndex, 10)
    if (index < 0 || index >= this.functions.length) {
      this.showError("Function not found")
      return
    }

    const func = this.functions[index]
    if (!confirm(`Are you sure you want to delete the function "${func.name}"?`)) {
      return
    }

    this.functions.splice(index, 1)
    this.renderFunctionList()
    this.showSuccess("Function deleted")

    // Trigger auto-save if not a new assistant
    if (!this.isNewValue) {
      this.debouncedSave()
    }
  }

  saveFunction() {
    // Get modal elements
    const nameInput = this.getModalElement("functionName")
    const descriptionInput = this.getModalElement("functionDescription")
    const parametersInput = this.getModalElement("functionParameters")
    const parametersError = this.getModalElement("functionParametersError")
    const editIndexInput = this.getModalElement("functionEditIndex")
    const strictCheckbox = this.getModalElement("functionStrict")

    // Validate function data
    const name = nameInput?.value.trim() || ""
    const description = descriptionInput?.value.trim() || ""
    const parametersText = parametersInput?.value.trim() || ""

    if (!name) {
      this.showError("Function name is required")
      nameInput?.focus()
      return
    }

    // Validate function name format
    if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name)) {
      this.showError("Function name must start with a letter or underscore and contain only alphanumeric characters")
      nameInput?.focus()
      return
    }

    if (!description) {
      this.showError("Function description is required")
      descriptionInput?.focus()
      return
    }

    // Validate JSON parameters
    let parameters
    try {
      parameters = JSON.parse(parametersText)
      parametersInput?.classList.remove("is-invalid")
    } catch (e) {
      parametersInput?.classList.add("is-invalid")
      if (parametersError) parametersError.textContent = `Invalid JSON: ${e.message}`
      this.showError("Invalid JSON in parameters")
      return
    }

    // Validate that parameters is an object with type "object"
    if (typeof parameters !== "object" || parameters.type !== "object") {
      parametersInput?.classList.add("is-invalid")
      if (parametersError) parametersError.textContent = "Parameters must be a JSON Schema with type 'object'"
      this.showError("Parameters must be a JSON Schema with type 'object'")
      return
    }

    const editIndex = parseInt(editIndexInput?.value || "-1", 10)
    const isEditing = editIndex >= 0

    // Check for duplicate names (excluding the current function if editing)
    const nameExists = this.functions.some((f, i) => {
      if (isEditing && i === editIndex) return false
      return f.name.toLowerCase() === name.toLowerCase()
    })

    if (nameExists) {
      this.showError(`A function with the name "${name}" already exists`)
      nameInput?.focus()
      return
    }

    const functionData = {
      name: name,
      description: description,
      parameters: parameters,
      strict: strictCheckbox?.checked || false
    }

    if (isEditing) {
      this.functions[editIndex] = functionData
      this.showSuccess("Function updated")
    } else {
      this.functions.push(functionData)
      this.showSuccess("Function added")
    }

    this.hideFunctionModal()
    this.renderFunctionList()

    // Trigger auto-save if not a new assistant
    if (!this.isNewValue) {
      this.debouncedSave()
    }
  }

  renderFunctionList() {
    if (!this.hasFunctionListTarget) return

    if (this.functions.length === 0) {
      this.functionListTarget.innerHTML = `
        <div class="text-muted small text-center py-2 empty-functions-message">
          <i class="bi bi-info-circle"></i> No functions defined
        </div>
      `
      return
    }

    const html = this.functions.map((func, index) => {
      const paramCount = Object.keys(func.parameters?.properties || {}).length
      const paramLabel = paramCount === 1 ? "1 parameter" : `${paramCount} parameters`
      const truncatedDesc = func.description?.length > 60
        ? func.description.substring(0, 60) + "..."
        : func.description

      return `
        <div class="function-item card mb-2" data-function-index="${index}" data-function-data='${JSON.stringify(func).replace(/'/g, "&#39;")}'>
          <div class="card-body py-2 px-3">
            <div class="d-flex justify-content-between align-items-start">
              <div class="function-info flex-grow-1">
                <strong class="function-name">${this.escapeHtml(func.name)}</strong>
                <br>
                <small class="text-muted function-description">${this.escapeHtml(truncatedDesc)}</small>
                ${paramCount > 0 ? `<br><small class="text-muted"><i class="bi bi-box"></i> ${paramLabel}</small>` : ""}
              </div>
              <div class="function-actions btn-group btn-group-sm">
                <button type="button"
                        class="btn btn-outline-secondary"
                        data-action="click->assistant-playground#editFunction"
                        data-function-index="${index}"
                        title="Edit">
                  <i class="bi bi-pencil"></i>
                </button>
                <button type="button"
                        class="btn btn-outline-danger"
                        data-action="click->assistant-playground#deleteFunction"
                        data-function-index="${index}"
                        title="Delete">
                  <i class="bi bi-trash"></i>
                </button>
              </div>
            </div>
          </div>
        </div>
      `
    }).join("")

    this.functionListTarget.innerHTML = html
  }

  showFunctionModal() {
    const modalElement = this.getModalElement("functionEditorModal")
    if (!modalElement) return
    const modal = new Modal(modalElement)
    modal.show()
  }

  hideFunctionModal() {
    const modalElement = this.getModalElement("functionEditorModal")
    if (!modalElement) return
    const modal = Modal.getInstance(modalElement)
    if (modal) {
      modal.hide()
    }
  }

  escapeHtml(text) {
    if (!text) return ""
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

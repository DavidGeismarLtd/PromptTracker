import { Controller } from "@hotwired/stimulus"

/**
 * Resizable Columns Stimulus Controller
 * Allows users to resize table columns by dragging column borders
 * Persists column widths in sessionStorage
 */
export default class extends Controller {
  static values = {
    storageKey: { type: String, default: "tableColumnWidths" }
  }

  connect() {
    this.table = this.element.querySelector("table")
    if (!this.table) return

    this.isResizing = false
    this.currentColumn = null
    this.startX = 0
    this.startWidth = 0

    this.initializeResizeHandles()
    this.loadColumnWidths()

    // Bind event handlers
    this.boundMouseMove = this.onMouseMove.bind(this)
    this.boundMouseUp = this.onMouseUp.bind(this)

    // Listen for Turbo Stream updates to reinitialize handles for new rows
    this.boundTurboStreamRender = this.onTurboStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundTurboStreamRender)
  }

  disconnect() {
    // Clean up event listeners
    if (this.isResizing) {
      document.removeEventListener("mousemove", this.boundMouseMove)
      document.removeEventListener("mouseup", this.boundMouseUp)
    }
    document.removeEventListener("turbo:before-stream-render", this.boundTurboStreamRender)
  }

  /**
   * Handle Turbo Stream renders to apply column widths to new rows
   */
  onTurboStreamRender(event) {
    // Wait for the DOM to update, then apply saved widths to new rows
    setTimeout(() => {
      this.applyWidthsToNewRows()
    }, 0)
  }

  /**
   * Apply saved column widths to newly added rows
   */
  applyWidthsToNewRows() {
    const saved = sessionStorage.getItem(this.storageKeyValue)
    if (!saved) return

    try {
      const widths = JSON.parse(saved)
      const headers = this.table.querySelectorAll("thead th")

      headers.forEach((header, index) => {
        const columnKey = header.dataset.column
        if (columnKey && widths[columnKey]) {
          const width = widths[columnKey]

          // Apply to all cells in this column
          const rows = this.table.querySelectorAll("tbody tr")
          rows.forEach(row => {
            const cell = row.cells[index]
            if (cell && !cell.style.width) {
              cell.style.width = `${width}px`
            }
          })
        }
      })
    } catch (e) {
      console.error("Failed to apply column widths to new rows:", e)
    }
  }

  /**
   * Initialize resize handles for all table headers
   */
  initializeResizeHandles() {
    const headers = this.table.querySelectorAll("thead th")

    headers.forEach((header, index) => {
      // Skip if this is the last column (no need to resize)
      if (index === headers.length - 1) return

      // Skip if handle already exists
      if (header.querySelector(".column-resize-handle")) return

      // Create resize handle
      const resizeHandle = document.createElement("div")
      resizeHandle.className = "column-resize-handle"
      resizeHandle.dataset.columnIndex = index

      // Position the handle
      header.style.position = "relative"
      header.appendChild(resizeHandle)

      // Add event listeners
      resizeHandle.addEventListener("mousedown", this.onMouseDown.bind(this))
    })
  }

  /**
   * Handle mouse down on resize handle
   */
  onMouseDown(event) {
    event.preventDefault()
    event.stopPropagation()

    this.isResizing = true
    this.currentColumn = event.target.parentElement
    this.startX = event.pageX
    this.startWidth = this.currentColumn.offsetWidth

    // Add document-level event listeners
    document.addEventListener("mousemove", this.boundMouseMove)
    document.addEventListener("mouseup", this.boundMouseUp)

    // Add resizing class to body for cursor
    document.body.classList.add("resizing-column")
  }

  /**
   * Handle mouse move during resize
   */
  onMouseMove(event) {
    if (!this.isResizing) return

    event.preventDefault()

    const diff = event.pageX - this.startX
    const newWidth = Math.max(50, this.startWidth + diff) // Minimum width of 50px

    // Update column width
    this.currentColumn.style.width = `${newWidth}px`

    // Also update the corresponding cells in the body
    const columnIndex = parseInt(this.currentColumn.cellIndex)
    const rows = this.table.querySelectorAll("tbody tr")
    rows.forEach(row => {
      const cell = row.cells[columnIndex]
      if (cell) {
        cell.style.width = `${newWidth}px`
      }
    })
  }

  /**
   * Handle mouse up to finish resize
   */
  onMouseUp(event) {
    if (!this.isResizing) return

    this.isResizing = false
    document.body.classList.remove("resizing-column")

    // Remove document-level event listeners
    document.removeEventListener("mousemove", this.boundMouseMove)
    document.removeEventListener("mouseup", this.boundMouseUp)

    // Save the new column widths
    this.saveColumnWidths()

    this.currentColumn = null
  }

  /**
   * Save column widths to sessionStorage
   */
  saveColumnWidths() {
    const headers = this.table.querySelectorAll("thead th")
    const widths = {}

    headers.forEach((header, index) => {
      const columnKey = header.dataset.column
      if (columnKey) {
        widths[columnKey] = header.offsetWidth
      }
    })

    sessionStorage.setItem(this.storageKeyValue, JSON.stringify(widths))
  }

  /**
   * Load column widths from sessionStorage
   */
  loadColumnWidths() {
    const saved = sessionStorage.getItem(this.storageKeyValue)
    if (!saved) return

    try {
      const widths = JSON.parse(saved)
      const headers = this.table.querySelectorAll("thead th")

      headers.forEach((header, index) => {
        const columnKey = header.dataset.column
        if (columnKey && widths[columnKey]) {
          const width = widths[columnKey]
          header.style.width = `${width}px`

          // Also update the corresponding cells in the body
          const rows = this.table.querySelectorAll("tbody tr")
          rows.forEach(row => {
            const cell = row.cells[index]
            if (cell) {
              cell.style.width = `${width}px`
            }
          })
        }
      })
    } catch (e) {
      console.error("Failed to load column widths:", e)
    }
  }
}

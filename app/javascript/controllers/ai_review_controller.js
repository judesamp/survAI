import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]

  connect() {
    console.log("AI Review controller connected")
    this.originalText = this.buttonTarget.value

    // Listen for turbo submit events
    this.boundHandleSubmitStart = this.handleSubmitStart.bind(this)
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-start", this.boundHandleSubmitStart)
    document.addEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
  }

  start(event) {
    console.log("Form submission started", event)
    // Don't prevent default - let the form submit

    // Show loading state immediately
    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("opacity-75", "cursor-not-allowed")
    this.buttonTarget.value = "🤖 Analyzing..."

    // Show loading content in review area
    const reviewContent = document.getElementById("ai_review_content")
    if (reviewContent) {
      reviewContent.innerHTML = `
        <div class="bg-gradient-to-r from-purple-50 to-indigo-50 shadow-lg rounded-lg overflow-hidden">
          <div class="px-6 py-4 bg-gradient-to-r from-purple-600 to-indigo-600">
            <h3 class="text-lg font-semibold text-white flex items-center gap-2">
              🤖 AI Survey Review
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-white bg-opacity-20 text-white">
                Analyzing...
              </span>
            </h3>
          </div>
          <div class="p-6">
            <div class="flex items-center justify-center py-8">
              <div class="text-center">
                <svg class="animate-spin h-8 w-8 text-purple-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <h4 class="text-lg font-medium text-gray-900 mb-2">AI is analyzing your survey...</h4>
                <p class="text-sm text-gray-600 mb-4">
                  Our AI is reviewing your questions, survey flow, and overall structure.
                </p>
                <div class="space-y-2 text-sm text-gray-500">
                  <p>• Evaluating question quality and clarity</p>
                  <p>• Checking survey flow and logic</p>
                  <p>• Identifying missing elements</p>
                  <p>• Generating improvement suggestions</p>
                </div>
                <p class="text-xs text-purple-600 mt-4 font-medium">
                  This usually takes 10-30 seconds...
                </p>
              </div>
            </div>
          </div>
        </div>
      `
    }
  }

  stop() {
    console.log("Stopping AI review loading state")
    // Reset button state
    this.buttonTarget.disabled = false
    this.buttonTarget.classList.remove("opacity-75", "cursor-not-allowed")
    this.buttonTarget.value = this.originalText
  }

  handleSubmitStart(event) {
    console.log("Turbo submit start:", event)
    // Check if this was our form
    if (event.target === this.formTarget) {
      console.log("Our form is submitting!")
    }
  }

  handleSubmitEnd(event) {
    console.log("Turbo submit end:", event)
    // Check if this was our form
    if (event.target === this.formTarget) {
      console.log("Our form completed, stopping loading state")
      this.stop()
    }
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("turbo:submit-start", this.boundHandleSubmitStart)
    document.removeEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
  }
}
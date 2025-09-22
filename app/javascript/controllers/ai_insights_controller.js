import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]

  connect() {
    console.log("AI Insights controller connected")
    this.originalButtonText = this.buttonTarget.value

    // Listen for turbo submit events
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
  }

  start(event) {
    console.log("Starting AI insights analysis", event)

    // Show loading state on button
    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("opacity-75", "cursor-not-allowed")
    this.buttonTarget.value = "🤖 Analyzing..."

    // Show loading content in insights area
    const insightsContent = document.getElementById("ai_insights_content")
    if (insightsContent) {
      insightsContent.innerHTML = `
        <div class="bg-gradient-to-r from-purple-50 to-indigo-50 shadow-lg rounded-lg overflow-hidden">
          <div class="px-6 py-4 bg-gradient-to-r from-purple-600 to-indigo-600">
            <h3 class="text-lg font-semibold text-white flex items-center gap-2">
              🤖 AI Survey Insights
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-white bg-opacity-20 text-white">
                Analyzing...
              </span>
            </h3>
          </div>
          <div class="p-6">
            <div class="flex items-center justify-center py-12">
              <div class="text-center">
                <svg class="animate-spin h-12 w-12 text-purple-600 mx-auto mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <h4 class="text-lg font-medium text-gray-900 mb-2">AI is analyzing your survey data...</h4>
                <p class="text-sm text-gray-600 mb-6">
                  Our AI is examining responses, identifying patterns, and generating actionable insights.
                </p>
                <div class="space-y-2 text-sm text-gray-500">
                  <p>📊 Analyzing response patterns and trends</p>
                  <p>🔍 Identifying key satisfaction drivers</p>
                  <p>⚠️ Detecting areas needing attention</p>
                  <p>🎯 Generating actionable recommendations</p>
                  <p>🏢 Evaluating department-specific insights</p>
                </div>
                <p class="text-xs text-purple-600 mt-6 font-medium">
                  This usually takes 15-45 seconds depending on response volume...
                </p>
              </div>
            </div>
          </div>
        </div>
      `
    }
  }

  handleSubmitEnd(event) {
    console.log("AI insights form submission ended", event)
    // Check if this was our form
    if (event.target === this.formTarget) {
      this.stop()
    }
  }

  stop() {
    console.log("Stopping AI insights loading state")

    // Reset button
    this.buttonTarget.disabled = false
    this.buttonTarget.classList.remove("opacity-75", "cursor-not-allowed")
    this.buttonTarget.value = this.originalButtonText
  }

  disconnect() {
    // Clean up event listeners
    document.removeEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
  }
}
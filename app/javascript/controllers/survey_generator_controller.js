import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form", "loadingContainer"]

  connect() {
    console.log("Survey generator controller connected")
    this.originalButtonText = this.buttonTarget.value

    // Listen for form submission
    this.boundHandleSubmitEnd = this.handleSubmitEnd.bind(this)
    document.addEventListener("turbo:submit-end", this.boundHandleSubmitEnd)
  }

  start(event) {
    console.log("Starting survey generation", event)

    // Disable button and show loading state
    this.buttonTarget.disabled = true
    this.buttonTarget.classList.add("opacity-75", "cursor-not-allowed")
    this.buttonTarget.value = "🤖 Generating..."

    // Show loading container with progress steps
    this.showLoadingState()

    // Start progress animation
    this.startProgressAnimation()
  }

  showLoadingState() {
    // Create or update loading container
    const container = this.hasLoadingContainerTarget ? this.loadingContainerTarget : this.createLoadingContainer()

    container.innerHTML = `
      <div class="fixed inset-0 bg-gray-600 bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg shadow-xl p-8 max-w-md w-full mx-4">
          <div class="flex flex-col items-center">
            <svg class="animate-spin h-12 w-12 text-sky-600 mb-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>

            <h3 class="text-lg font-semibold text-gray-900 mb-4">Generating Your Survey</h3>

            <div class="w-full space-y-3" id="progress-steps">
              <div class="step-item" data-step="1">
                <div class="flex items-center">
                  <div class="step-indicator w-8 h-8 rounded-full bg-sky-600 text-white flex items-center justify-center text-sm font-medium">
                    ✓
                  </div>
                  <div class="ml-3 text-sm font-medium text-gray-900">Analyzing your requirements</div>
                </div>
              </div>

              <div class="step-item" data-step="2">
                <div class="flex items-center">
                  <div class="step-indicator w-8 h-8 rounded-full bg-gray-300 text-gray-600 flex items-center justify-center text-sm font-medium">
                    2
                  </div>
                  <div class="ml-3 text-sm text-gray-600">Connecting to AI engine</div>
                </div>
              </div>

              <div class="step-item" data-step="3">
                <div class="flex items-center">
                  <div class="step-indicator w-8 h-8 rounded-full bg-gray-300 text-gray-600 flex items-center justify-center text-sm font-medium">
                    3
                  </div>
                  <div class="ml-3 text-sm text-gray-600">Creating survey structure</div>
                </div>
              </div>

              <div class="step-item" data-step="4">
                <div class="flex items-center">
                  <div class="step-indicator w-8 h-8 rounded-full bg-gray-300 text-gray-600 flex items-center justify-center text-sm font-medium">
                    4
                  </div>
                  <div class="ml-3 text-sm text-gray-600">Generating relevant questions</div>
                </div>
              </div>

              <div class="step-item" data-step="5">
                <div class="flex items-center">
                  <div class="step-indicator w-8 h-8 rounded-full bg-gray-300 text-gray-600 flex items-center justify-center text-sm font-medium">
                    5
                  </div>
                  <div class="ml-3 text-sm text-gray-600">Finalizing your survey</div>
                </div>
              </div>
            </div>

            <p class="mt-6 text-xs text-gray-500 text-center">
              This usually takes 15-30 seconds. AI is crafting questions specifically for your needs.
            </p>
          </div>
        </div>
      </div>
    `

    container.style.display = 'block'
  }

  createLoadingContainer() {
    const container = document.createElement('div')
    container.setAttribute('data-survey-generator-target', 'loadingContainer')
    container.style.display = 'none'
    document.body.appendChild(container)
    return container
  }

  startProgressAnimation() {
    this.currentStep = 1
    this.progressInterval = setInterval(() => {
      this.updateProgress()
    }, 3000) // Update every 3 seconds
  }

  updateProgress() {
    if (this.currentStep < 5) {
      this.currentStep++

      const steps = document.querySelectorAll('.step-item')
      steps.forEach((step) => {
        const stepNum = parseInt(step.dataset.step)
        const indicator = step.querySelector('.step-indicator')
        const text = step.querySelector('.ml-3')

        if (stepNum < this.currentStep) {
          // Completed step
          indicator.className = 'step-indicator w-8 h-8 rounded-full bg-sky-600 text-white flex items-center justify-center text-sm font-medium'
          indicator.innerHTML = '✓'
          text.className = 'ml-3 text-sm font-medium text-gray-900'
        } else if (stepNum === this.currentStep) {
          // Current step - add animation
          indicator.className = 'step-indicator w-8 h-8 rounded-full bg-sky-600 text-white flex items-center justify-center text-sm font-medium animate-pulse'
          indicator.innerHTML = stepNum.toString()
          text.className = 'ml-3 text-sm font-medium text-gray-900'
        } else {
          // Future step
          indicator.className = 'step-indicator w-8 h-8 rounded-full bg-gray-300 text-gray-600 flex items-center justify-center text-sm font-medium'
          indicator.innerHTML = stepNum.toString()
          text.className = 'ml-3 text-sm text-gray-600'
        }
      })
    }
  }

  handleSubmitEnd(event) {
    console.log("Form submission ended", event)
    // Check if this was our form
    if (event.target === this.formTarget) {
      this.stop()
    }
  }

  stop() {
    console.log("Stopping survey generation loading state")

    // Clear progress animation
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
    }

    // Reset button
    this.buttonTarget.disabled = false
    this.buttonTarget.classList.remove("opacity-75", "cursor-not-allowed")
    this.buttonTarget.value = this.originalButtonText

    // Hide loading container
    if (this.hasLoadingContainerTarget) {
      this.loadingContainerTarget.style.display = 'none'
    }
  }

  disconnect() {
    // Clean up
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
    }
    document.removeEventListener("turbo:submit-end", this.boundHandleSubmitEnd)

    // Remove loading container if it exists
    if (this.hasLoadingContainerTarget && this.loadingContainerTarget.parentNode) {
      this.loadingContainerTarget.parentNode.removeChild(this.loadingContainerTarget)
    }
  }
}
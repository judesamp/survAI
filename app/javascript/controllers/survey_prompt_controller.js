import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="survey-prompt"
export default class extends Controller {
  static targets = ["prompt", "advancedPanel", "advancedIcon", "targetAudience", "organizationContext"]

  connect() {
    this.isAdvancedOpen = false
  }

  // Action to handle example prompt clicks
  selectExample(event) {
    const prompt = event.currentTarget.dataset.prompt
    this.promptTarget.value = prompt
    this.promptTarget.focus()
  }

  // Toggle advanced options panel
  toggleAdvanced(event) {
    event.preventDefault()
    this.isAdvancedOpen = !this.isAdvancedOpen

    if (this.hasAdvancedPanelTarget) {
      if (this.isAdvancedOpen) {
        // Show panel with smooth animation
        this.advancedPanelTarget.classList.remove('hidden')
        setTimeout(() => {
          this.advancedPanelTarget.classList.add('show')
        }, 10)

        // Rotate icon
        if (this.hasAdvancedIconTarget) {
          this.advancedIconTarget.style.transform = 'rotate(180deg)'
        }

        // Focus first input if available
        if (this.hasTargetAudienceTarget) {
          this.targetAudienceTarget.focus()
        }
      } else {
        // Hide panel
        this.advancedPanelTarget.classList.remove('show')
        setTimeout(() => {
          this.advancedPanelTarget.classList.add('hidden')
        }, 200)

        // Reset icon rotation
        if (this.hasAdvancedIconTarget) {
          this.advancedIconTarget.style.transform = 'rotate(0deg)'
        }
      }
    }
  }
}

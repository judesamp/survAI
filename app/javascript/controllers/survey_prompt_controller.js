import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="survey-prompt"
export default class extends Controller {
  static targets = ["prompt"]

  // Action to handle example prompt clicks
  selectExample(event) {
    const prompt = event.currentTarget.dataset.prompt
    this.promptTarget.value = prompt
    this.promptTarget.focus()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { surveyId: Number }

  connect() {
    console.log(`🔗 Survey Data Generation Controller: Connecting to survey ${this.surveyIdValue}`)

    // Subscribe to the Turbo Stream and manually process messages
    this.setupTurboStreamProcessing()
  }

  setupTurboStreamProcessing() {
    // Listen for Turbo Stream messages on the document
    document.addEventListener('turbo:before-stream-render', (event) => {
      console.log('🎯 Turbo Stream event detected:', event.detail)
    })

    // Also set up a manual check for ActionCable messages
    if (window.App && window.App.cable) {
      console.log('📡 Using existing ActionCable connection')
    } else {
      console.log('🔌 Setting up new ActionCable connection')
      this.setupActionCable()
    }
  }

  setupActionCable() {
    // Import and create consumer
    import("@rails/actioncable").then(({ createConsumer }) => {
      this.consumer = createConsumer()

      this.subscription = this.consumer.subscriptions.create(
        {
          channel: "Turbo::StreamsChannel",
          signed_stream_name: this.signedStreamName
        },
        {
          connected: () => {
            console.log(`✅ Connected to survey ${this.surveyIdValue} data generation stream`)
          },

          disconnected: () => {
            console.log(`❌ Disconnected from survey ${this.surveyIdValue} data generation stream`)
          },

          received: (data) => {
            console.log("📡 Received data from ActionCable:", data)
            this.processTurboStream(data)
          }
        }
      )
    })
  }

  processTurboStream(data) {
    if (typeof data === 'string' && data.includes('<turbo-stream')) {
      console.log("🔄 Processing Turbo Stream manually...")

      // Create a temporary element to parse the turbo-stream
      const tempDiv = document.createElement('div')
      tempDiv.innerHTML = data

      const turboStreamElement = tempDiv.querySelector('turbo-stream')
      if (turboStreamElement) {
        console.log("🎯 Found turbo-stream element:", turboStreamElement.outerHTML)

        const action = turboStreamElement.getAttribute('action')
        const target = turboStreamElement.getAttribute('target')
        const targetElement = document.getElementById(target)

        if (targetElement) {
          console.log(`⚡ Applying ${action} action to ${target}`)

          switch (action) {
            case 'replace':
              targetElement.outerHTML = turboStreamElement.innerHTML
              break
            case 'prepend':
              targetElement.insertAdjacentHTML('afterbegin', turboStreamElement.innerHTML)
              break
            case 'append':
              targetElement.insertAdjacentHTML('beforeend', turboStreamElement.innerHTML)
              break
            default:
              console.log(`⚠️ Unknown action: ${action}`)
          }
        } else {
          console.log(`❌ Target element not found: ${target}`)
        }
      }
    }
  }

  get signedStreamName() {
    // This should match the signed stream name from the turbo_stream_from helper
    return `survey_${this.surveyIdValue}_data_generation`
  }

  disconnect() {
    console.log(`🔌 Disconnecting survey ${this.surveyIdValue} data generation controller`)
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.consumer) {
      this.consumer.disconnect()
    }
  }
}
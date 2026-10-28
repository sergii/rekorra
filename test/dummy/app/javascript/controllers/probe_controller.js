import { Controller } from "@hotwired/stimulus"

// Test host only: records that Stimulus controllers connect to the live page.
export default class extends Controller {
  connect() {
    window.__rekorraProbeConnected = (window.__rekorraProbeConnected || 0) + 1
    this.element.dataset.rkProbeConnected = "true"
  }
}

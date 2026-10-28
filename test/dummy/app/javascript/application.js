import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import ProbeController from "controllers/probe_controller"

window.Stimulus = Application.start()
window.Stimulus.register("rekorra-probe", ProbeController)

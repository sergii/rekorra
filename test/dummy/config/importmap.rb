pin "application", to: "application.js"
pin "controllers/probe_controller", to: "controllers/probe_controller.js"
# Real browser acceptance host owns its importmap pins.
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"

# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "dashboard", to: "dashboard.js"
pin_all_from "app/javascript/dashboard", under: "dashboard"
pin "ai_analysis_poller", to: "ai_analysis_poller.js"
pin "stimulus", to: "@hotwired/stimulus"

pin "chart.js/auto", to: "https://cdn.jsdelivr.net/npm/chart.js@4.4.1/auto/auto.js"
pin "@kurkle/color", to: "https://cdn.jsdelivr.net/npm/@kurkle/color@0.3.2/dist/color.esm.js"

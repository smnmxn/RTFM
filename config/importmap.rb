# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/actioncable", to: "actioncable.esm.js"
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/modular/sortable.esm.js"
pin "motion", to: "https://cdn.jsdelivr.net/npm/motion@12.34.0/+esm"

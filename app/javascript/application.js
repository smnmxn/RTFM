// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Import and register controllers
import InlineEditController from "controllers/inline_edit_controller"
import ArrayEditController from "controllers/array_edit_controller"
import TabsController from "controllers/tabs_controller"
import InboxRowController from "controllers/inbox_row_controller"

application.register("inline-edit", InlineEditController)
application.register("array-edit", ArrayEditController)
application.register("tabs", TabsController)
application.register("inbox-row", InboxRowController)

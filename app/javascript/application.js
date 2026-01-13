// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Import and register controllers
import InlineEditController from "controllers/inline_edit_controller"
import ArrayEditController from "controllers/array_edit_controller"
import TabsController from "controllers/tabs_controller"
import InboxRowController from "controllers/inbox_row_controller"
import ClipboardController from "controllers/clipboard_controller"
import DropdownController from "controllers/dropdown_controller"
import ArticlesRowController from "controllers/articles_row_controller"
import ArticlesSectionController from "controllers/articles_section_controller"
import OnboardingQuestionsController from "controllers/onboarding_questions_controller"
import ContextualQuestionsController from "controllers/contextual_questions_controller"
import FeedbackController from "controllers/feedback_controller"

application.register("inline-edit", InlineEditController)
application.register("array-edit", ArrayEditController)
application.register("tabs", TabsController)
application.register("inbox-row", InboxRowController)
application.register("clipboard", ClipboardController)
application.register("dropdown", DropdownController)
application.register("articles-row", ArticlesRowController)
application.register("articles-section", ArticlesSectionController)
application.register("onboarding-questions", OnboardingQuestionsController)
application.register("contextual-questions", ContextualQuestionsController)
application.register("feedback", FeedbackController)

// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"

// DEBUG: Log all Turbo Stream events to track what's causing page updates
document.addEventListener("turbo:before-stream-render", (event) => {
  const action = event.target.getAttribute("action")
  const target = event.target.getAttribute("target")
  console.log(`[Turbo Stream] action=${action} target=${target}`)
})

document.addEventListener("turbo:before-render", (event) => {
  console.log("[Turbo] before-render - page is about to be replaced")
})

document.addEventListener("turbo:render", (event) => {
  console.log("[Turbo] render - page was replaced")
})

document.addEventListener("turbo:before-cache", (event) => {
  console.log("[Turbo] before-cache")
})

document.addEventListener("turbo:before-fetch-request", (event) => {
  console.log("[Turbo] before-fetch-request:", event.detail.url?.toString())
})

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
import StepImageController from "controllers/step_image_controller"
import LogoUploadController from "controllers/logo_upload_controller"
import InboxController from "controllers/inbox_controller"
import RegenerateModalController from "controllers/regenerate_modal_controller"
import NewArticleModalController from "controllers/new_article_modal_controller"
import ActivityStagesController from "controllers/activity_stages_controller"
import ArticlePreviewController from "controllers/article_preview_controller"

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
application.register("step-image", StepImageController)
application.register("logo-upload", LogoUploadController)
application.register("inbox", InboxController)
application.register("regenerate-modal", RegenerateModalController)
application.register("new-article-modal", NewArticleModalController)
application.register("activity-stages", ActivityStagesController)
application.register("article-preview", ArticlePreviewController)

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_18_090553) do
  create_table "articles", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "generation_status", default: "pending", null: false
    t.integer "project_id", null: false
    t.datetime "published_at"
    t.integer "recommendation_id", null: false
    t.string "review_status", default: "unreviewed", null: false
    t.datetime "reviewed_at"
    t.integer "section_id"
    t.string "status", default: "draft", null: false
    t.json "structured_content"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_articles_on_project_id"
    t.index ["recommendation_id"], name: "index_articles_on_recommendation_id"
    t.index ["review_status"], name: "index_articles_on_review_status"
    t.index ["section_id"], name: "index_articles_on_section_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "analysis_commit_sha"
    t.json "analysis_metadata"
    t.string "analysis_status"
    t.text "analysis_summary"
    t.datetime "analyzed_at"
    t.datetime "created_at", null: false
    t.string "github_repo"
    t.integer "github_webhook_id"
    t.string "name"
    t.datetime "onboarding_started_at"
    t.string "onboarding_step"
    t.text "project_overview"
    t.datetime "sections_generation_started_at"
    t.string "sections_generation_status"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "webhook_secret"
    t.index ["onboarding_step"], name: "index_projects_on_onboarding_step"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["user_id"], name: "index_projects_on_user_id"
  end

  create_table "recommendations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "justification"
    t.integer "project_id", null: false
    t.datetime "rejected_at"
    t.integer "section_id"
    t.integer "source_update_id"
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_recommendations_on_project_id"
    t.index ["section_id"], name: "index_recommendations_on_section_id"
    t.index ["source_update_id"], name: "index_recommendations_on_source_update_id"
  end

  create_table "sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.text "justification"
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.integer "project_id", null: false
    t.datetime "recommendations_started_at"
    t.string "recommendations_status"
    t.string "section_type", default: "template", null: false
    t.string "slug", null: false
    t.string "status", default: "accepted", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: true
    t.index ["project_id", "position"], name: "index_sections_on_project_id_and_position"
    t.index ["project_id", "slug"], name: "index_sections_on_project_id_and_slug", unique: true
    t.index ["project_id"], name: "index_sections_on_project_id"
  end

  create_table "updates", force: :cascade do |t|
    t.string "analysis_status"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.datetime "published_at"
    t.integer "pull_request_number"
    t.string "pull_request_url"
    t.json "recommended_articles"
    t.text "social_snippet"
    t.string "status", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_updates_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "github_token"
    t.string "github_uid"
    t.string "github_username"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["github_uid"], name: "index_users_on_github_uid", unique: true
  end

  add_foreign_key "articles", "projects"
  add_foreign_key "articles", "recommendations"
  add_foreign_key "articles", "sections"
  add_foreign_key "projects", "users"
  add_foreign_key "recommendations", "projects"
  add_foreign_key "recommendations", "sections"
  add_foreign_key "recommendations", "updates", column: "source_update_id"
  add_foreign_key "sections", "projects"
  add_foreign_key "updates", "projects"
end

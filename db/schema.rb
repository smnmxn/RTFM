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

ActiveRecord::Schema[8.1].define(version: 2026_01_14_180936) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "articles", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "generation_status", default: "pending", null: false
    t.integer "position", default: 0
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
    t.index ["section_id", "position"], name: "index_articles_on_section_id_and_position"
    t.index ["section_id"], name: "index_articles_on_section_id"
  end

  create_table "github_app_installations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "account_login", null: false
    t.string "account_type", null: false
    t.datetime "created_at", null: false
    t.bigint "github_installation_id", null: false
    t.datetime "suspended_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["account_login"], name: "index_github_app_installations_on_account_login"
    t.index ["github_installation_id"], name: "index_github_app_installations_on_github_installation_id", unique: true
    t.index ["user_id"], name: "index_github_app_installations_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "analysis_commit_sha"
    t.json "analysis_metadata"
    t.string "analysis_status"
    t.text "analysis_summary"
    t.datetime "analyzed_at"
    t.json "contextual_questions"
    t.datetime "created_at", null: false
    t.bigint "github_app_installation_id"
    t.string "github_repo"
    t.string "name"
    t.datetime "onboarding_started_at"
    t.string "onboarding_step"
    t.text "project_overview"
    t.datetime "sections_generation_started_at"
    t.string "sections_generation_status"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.json "user_context"
    t.integer "user_id", null: false
    t.index ["github_app_installation_id"], name: "index_projects_on_github_app_installation_id"
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
    t.string "icon"
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

  create_table "step_images", force: :cascade do |t|
    t.bigint "article_id", null: false
    t.datetime "created_at", null: false
    t.integer "step_index", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "step_index"], name: "index_step_images_on_article_id_and_step_index", unique: true
    t.index ["article_id"], name: "index_step_images_on_article_id"
  end

  create_table "updates", force: :cascade do |t|
    t.string "analysis_status"
    t.string "commit_sha"
    t.string "commit_url"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "project_id", null: false
    t.datetime "published_at"
    t.integer "pull_request_number"
    t.string "pull_request_url"
    t.json "recommended_articles"
    t.text "social_snippet"
    t.string "source_type", default: "pull_request"
    t.string "status", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["commit_sha"], name: "index_updates_on_commit_sha"
    t.index ["project_id", "source_type"], name: "index_updates_on_project_id_and_source_type"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "articles", "projects"
  add_foreign_key "articles", "recommendations"
  add_foreign_key "articles", "sections"
  add_foreign_key "github_app_installations", "users"
  add_foreign_key "projects", "github_app_installations"
  add_foreign_key "projects", "users"
  add_foreign_key "recommendations", "projects"
  add_foreign_key "recommendations", "sections"
  add_foreign_key "recommendations", "updates", column: "source_update_id"
  add_foreign_key "sections", "projects"
  add_foreign_key "step_images", "articles"
  add_foreign_key "updates", "projects"
end

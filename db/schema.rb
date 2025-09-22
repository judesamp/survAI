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

ActiveRecord::Schema[8.0].define(version: 2025_09_22_164743) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "answers", force: :cascade do |t|
    t.bigint "response_id", null: false
    t.bigint "question_id", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id"], name: "index_answers_on_question_id"
    t.index ["response_id"], name: "index_answers_on_response_id"
  end

  create_table "assignments", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "user_id", null: false
    t.datetime "assigned_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "assigned_by_id", null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.bigint "response_id"
    t.datetime "reminder_sent_at"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_id"], name: "index_assignments_on_assigned_by_id"
    t.index ["completed"], name: "index_assignments_on_completed"
    t.index ["response_id"], name: "index_assignments_on_response_id"
    t.index ["survey_id", "user_id"], name: "index_assignments_on_survey_id_and_user_id", unique: true
    t.index ["survey_id"], name: "index_assignments_on_survey_id"
    t.index ["user_id"], name: "index_assignments_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.integer "plan"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.text "question_text"
    t.string "question_type"
    t.boolean "required"
    t.integer "position"
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["survey_id"], name: "index_questions_on_survey_id"
  end

  create_table "responses", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.bigint "user_id", null: false
    t.string "session_id"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "assignment_id"
    t.datetime "started_at"
    t.index ["assignment_id"], name: "index_responses_on_assignment_id"
    t.index ["started_at"], name: "index_responses_on_started_at"
    t.index ["survey_id"], name: "index_responses_on_survey_id"
    t.index ["user_id"], name: "index_responses_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "survey_insights", force: :cascade do |t|
    t.bigint "survey_id", null: false
    t.json "insights_data", null: false
    t.bigint "generated_by_id", null: false
    t.datetime "generated_at", null: false
    t.string "analysis_version", default: "1.0"
    t.text "summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_by_id"], name: "index_survey_insights_on_generated_by_id"
    t.index ["survey_id", "generated_at"], name: "index_survey_insights_on_survey_id_and_generated_at"
    t.index ["survey_id"], name: "index_survey_insights_on_survey_id"
  end

  create_table "surveys", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "slug"
    t.integer "status", default: 0
    t.integer "visibility", default: 0
    t.bigint "organization_id", null: false
    t.bigint "created_by_id", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.integer "response_limit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "ai_prompt"
    t.index ["created_by_id"], name: "index_surveys_on_created_by_id"
    t.index ["organization_id"], name: "index_surveys_on_organization_id"
    t.index ["slug"], name: "index_surveys_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest"
    t.string "first_name"
    t.string "last_name"
    t.integer "role", default: 0
    t.bigint "organization_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "department"
    t.date "hire_date"
    t.integer "status", default: 0, null: false
    t.datetime "last_survey_response_at"
    t.index ["department"], name: "index_users_on_department"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "answers", "questions"
  add_foreign_key "answers", "responses"
  add_foreign_key "assignments", "responses"
  add_foreign_key "assignments", "surveys"
  add_foreign_key "assignments", "users"
  add_foreign_key "assignments", "users", column: "assigned_by_id"
  add_foreign_key "questions", "surveys"
  add_foreign_key "responses", "assignments"
  add_foreign_key "responses", "surveys"
  add_foreign_key "responses", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "survey_insights", "surveys"
  add_foreign_key "survey_insights", "users", column: "generated_by_id"
  add_foreign_key "surveys", "organizations"
  add_foreign_key "surveys", "users", column: "created_by_id"
  add_foreign_key "users", "organizations"
end

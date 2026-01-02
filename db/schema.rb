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

ActiveRecord::Schema[7.2].define(version: 2026_01_02_160202) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_analyses", force: :cascade do |t|
    t.bigint "metric_id", null: false
    t.integer "analysis_type"
    t.json "parameters"
    t.json "results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.json "report"
    t.datetime "completed_at"
    t.index ["metric_id"], name: "index_ai_analyses_on_metric_id"
  end

  create_table "alerts", force: :cascade do |t|
    t.string "service"
    t.string "metric"
    t.float "value"
    t.float "threshold"
    t.string "status"
    t.string "severity"
    t.text "message"
    t.datetime "triggered_at"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "dashboard_settings", force: :cascade do |t|
    t.string "name", null: false
    t.text "settings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_dashboard_settings_on_name", unique: true
  end

  create_table "metrics", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "metric_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "display_name"
    t.string "unit"
  end

  create_table "ml_model_versions", force: :cascade do |t|
    t.string "model_type", null: false
    t.string "version", null: false
    t.string "status", default: "training", null: false
    t.jsonb "metadata", default: {}
    t.jsonb "metrics", default: {}
    t.datetime "trained_at"
    t.datetime "deployed_at"
    t.boolean "is_active", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_type", "is_active"], name: "index_ml_model_versions_on_model_type_and_is_active"
    t.index ["model_type"], name: "index_ml_model_versions_on_model_type"
    t.index ["status"], name: "index_ml_model_versions_on_status"
    t.index ["version"], name: "index_ml_model_versions_on_version"
  end

  create_table "reports", force: :cascade do |t|
    t.string "name", null: false
    t.string "report_type", default: "metrics", null: false
    t.string "format", default: "pdf", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "parameters", default: {}
    t.jsonb "metadata", default: {}
    t.datetime "generated_at"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_reports_on_created_at"
    t.index ["report_type"], name: "index_reports_on_report_type"
    t.index ["status"], name: "index_reports_on_status"
  end

  create_table "uploaded_files", force: :cascade do |t|
    t.string "name", null: false
    t.string "file_type", default: "other", null: false
    t.string "category"
    t.text "description"
    t.jsonb "metadata", default: {}
    t.string "uploadable_type"
    t.bigint "uploadable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_uploaded_files_on_category"
    t.index ["file_type"], name: "index_uploaded_files_on_file_type"
    t.index ["uploadable_type", "uploadable_id"], name: "index_uploaded_files_on_uploadable"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_analyses", "metrics"
end

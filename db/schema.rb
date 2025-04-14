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

ActiveRecord::Schema[7.2].define(version: 2025_03_27_230745) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "ai_analyses", force: :cascade do |t|
    t.bigint "metric_id", null: false
    t.integer "analysis_type"
    t.json "parameters"
    t.json "results"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  add_foreign_key "ai_analyses", "metrics"
end

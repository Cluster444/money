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

ActiveRecord::Schema[8.0].define(version: 2025_10_21_220000) do
  create_table "accounts", force: :cascade do |t|
    t.string "kind", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.bigint "debits", default: 0, null: false
    t.bigint "credits", default: 0, null: false
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "organization_id"
    t.index ["organization_id"], name: "index_accounts_on_organization_id"
  end

  create_table "adjustments", force: :cascade do |t|
    t.integer "account_id", null: false
    t.bigint "credit_amount"
    t.bigint "debit_amount"
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_adjustments_on_account_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_organizations_on_user_id"
  end

  create_table "schedules", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "amount"
    t.string "period"
    t.integer "frequency"
    t.date "starts_on", null: false
    t.date "ends_on"
    t.date "last_materialized_on"
    t.integer "credit_account_id", null: false
    t.integer "debit_account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "relative_account_id"
    t.index ["credit_account_id"], name: "index_schedules_on_credit_account_id"
    t.index ["debit_account_id"], name: "index_schedules_on_debit_account_id"
    t.index ["relative_account_id"], name: "index_schedules_on_relative_account_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "transfers", force: :cascade do |t|
    t.string "state", default: "pending", null: false
    t.bigint "amount", null: false
    t.date "pending_on", null: false
    t.date "posted_on"
    t.integer "debit_account_id", null: false
    t.integer "credit_account_id", null: false
    t.integer "schedule_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_account_id"], name: "index_transfers_on_credit_account_id"
    t.index ["debit_account_id"], name: "index_transfers_on_debit_account_id"
    t.index ["schedule_id"], name: "index_transfers_on_schedule_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "accounts", "organizations"
  add_foreign_key "adjustments", "accounts"
  add_foreign_key "organizations", "users"
  add_foreign_key "schedules", "accounts", column: "credit_account_id"
  add_foreign_key "schedules", "accounts", column: "debit_account_id"
  add_foreign_key "schedules", "accounts", column: "relative_account_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "transfers", "accounts", column: "credit_account_id"
  add_foreign_key "transfers", "accounts", column: "debit_account_id"
  add_foreign_key "transfers", "schedules"
end

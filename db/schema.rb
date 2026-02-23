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

ActiveRecord::Schema[8.1].define(version: 2026_02_22_000006) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "comments", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.bigint "federated_actor_id"
    t.bigint "parent_id"
    t.bigint "post_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "webstead_id", null: false
    t.index ["federated_actor_id"], name: "index_comments_on_federated_actor_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["post_id", "created_at"], name: "index_comments_on_post_id_and_created_at"
    t.index ["user_id"], name: "index_comments_on_user_id"
    t.index ["webstead_id"], name: "index_comments_on_webstead_id"
  end

  create_table "federated_actors", force: :cascade do |t|
    t.jsonb "actor_data"
    t.string "actor_type"
    t.string "actor_uri", null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "domain"
    t.string "inbox_url", null: false
    t.datetime "last_fetched_at"
    t.text "public_key"
    t.string "shared_inbox_url"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["actor_uri"], name: "index_federated_actors_on_actor_uri", unique: true
    t.index ["domain"], name: "index_federated_actors_on_domain"
  end

  create_table "followers", force: :cascade do |t|
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.bigint "federated_actor_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "webstead_id", null: false
    t.index ["federated_actor_id"], name: "index_followers_on_federated_actor_id"
    t.index ["webstead_id", "federated_actor_id"], name: "index_followers_on_webstead_and_actor", unique: true
    t.index ["webstead_id"], name: "index_followers_on_webstead_id"
  end

  create_table "posts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "published_at", precision: nil
    t.string "title", limit: 300, null: false
    t.datetime "updated_at", null: false
    t.bigint "webstead_id", null: false
    t.index ["webstead_id", "created_at"], name: "index_posts_on_webstead_id_and_created_at"
    t.index ["webstead_id", "published_at"], name: "index_posts_on_webstead_id_and_published_at"
    t.index ["webstead_id"], name: "index_posts_on_webstead_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.bigint "webstead_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
    t.index ["webstead_id"], name: "index_users_on_webstead_id"
  end

  create_table "websteads", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "custom_domain", limit: 253
    t.text "description"
    t.text "private_key"
    t.text "public_key"
    t.jsonb "settings", default: {}, null: false
    t.string "subdomain", limit: 63, null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["custom_domain"], name: "index_websteads_on_custom_domain", unique: true, where: "(custom_domain IS NOT NULL)"
    t.index ["settings"], name: "index_websteads_on_settings", using: :gin
    t.index ["subdomain"], name: "index_websteads_on_subdomain", unique: true
    t.index ["user_id"], name: "index_websteads_on_user_id", unique: true
    t.check_constraint "custom_domain IS NULL OR custom_domain::text ~ '^[a-z0-9][a-z0-9.-]*[a-z0-9]$'::text", name: "custom_domain_format_check"
    t.check_constraint "subdomain::text ~ '^[a-z0-9][a-z0-9-]*[a-z0-9]$'::text", name: "subdomain_format_check"
  end

  add_foreign_key "comments", "federated_actors"
  add_foreign_key "comments", "posts"
  add_foreign_key "comments", "users"
  add_foreign_key "comments", "websteads"
  add_foreign_key "followers", "federated_actors"
  add_foreign_key "followers", "websteads"
  add_foreign_key "posts", "websteads"
  add_foreign_key "users", "websteads"
end

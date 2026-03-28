class EnhanceComments < ActiveRecord::Migration[8.0]
  def change
    # Add foreign key for self-referential parent_id with cascade delete
    add_foreign_key :comments, :comments, column: :parent_id, on_delete: :cascade

    # Update existing foreign keys to add cascade behavior
    remove_foreign_key :comments, :posts
    add_foreign_key :comments, :posts, on_delete: :cascade

    remove_foreign_key :comments, :websteads
    add_foreign_key :comments, :websteads, on_delete: :cascade

    remove_foreign_key :comments, :users
    add_foreign_key :comments, :users, on_delete: :nullify

    remove_foreign_key :comments, :federated_actors
    add_foreign_key :comments, :federated_actors, on_delete: :nullify

    # Check constraint: exactly one author (user_id XOR federated_actor_id)
    add_check_constraint :comments,
      "(user_id IS NOT NULL AND federated_actor_id IS NULL) OR (user_id IS NULL AND federated_actor_id IS NOT NULL)",
      name: "comments_exactly_one_author"

    # Add index on created_at for chronological ordering
    add_index :comments, :created_at
  end
end

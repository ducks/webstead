class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :post, null: false, foreign_key: true, index: false
      t.references :webstead, null: false, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.references :federated_actor, foreign_key: true, null: true
      t.references :parent, foreign_key: { to_table: :comments, on_delete: :cascade }, null: true

      t.timestamps null: false
    end

    add_index :comments, [ :post_id, :created_at ]
    add_index :comments, :parent_id
    add_index :comments, :webstead_id

    execute <<-SQL
      ALTER TABLE comments
      ADD CONSTRAINT comment_author_check
      CHECK (
        (user_id IS NOT NULL AND federated_actor_id IS NULL) OR
        (user_id IS NULL AND federated_actor_id IS NOT NULL)
      );
    SQL
  end
end

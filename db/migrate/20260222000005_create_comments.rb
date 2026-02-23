class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :post, null: false, foreign_key: true, index: false
      t.references :webstead, null: false, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.references :federated_actor, foreign_key: true, null: true
      t.references :parent, foreign_key: false, null: true

      t.timestamps null: false
    end

    add_index :comments, [ :post_id, :created_at ]
  end
end

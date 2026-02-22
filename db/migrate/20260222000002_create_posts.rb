class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.references :webstead, null: false, foreign_key: true
      t.string :title, null: false, limit: 300
      t.text :body

      t.timestamp :published_at

      t.timestamps
    end

    add_index :posts, [ :webstead_id, :published_at ]
    add_index :posts, [ :webstead_id, :created_at ]
  end
end

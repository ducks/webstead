class CreateFollowers < ActiveRecord::Migration[8.0]
  def change
    create_table :followers do |t|
      t.references :webstead, null: false, foreign_key: true
      t.string :actor_uri, null: false
      t.string :inbox_url, null: false
      t.string :shared_inbox_url
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :followers, [:webstead_id, :actor_uri], unique: true
  end
end

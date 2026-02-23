class CreateFollowers < ActiveRecord::Migration[8.0]
  def change
    create_table :followers do |t|
      t.references :webstead, null: false, foreign_key: true
      t.references :federated_actor, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :followers, [:webstead_id, :federated_actor_id], unique: true, name: 'index_followers_on_webstead_and_actor'
  end
end

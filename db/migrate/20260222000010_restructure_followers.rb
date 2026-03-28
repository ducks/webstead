class RestructureFollowers < ActiveRecord::Migration[8.1]
  def change
    remove_index :followers, name: "index_followers_on_webstead_and_actor"
    remove_index :followers, name: "index_followers_on_federated_actor_id"

    remove_reference :followers, :federated_actor, foreign_key: true
    remove_column :followers, :status, :string

    add_column :followers, :actor_uri, :string, null: false
    add_column :followers, :inbox_url, :string, null: false
    add_column :followers, :shared_inbox_url, :string

    add_index :followers, [:webstead_id, :actor_uri], unique: true, name: "index_followers_on_webstead_and_actor"
    add_index :followers, :accepted_at
  end
end

class CreateFederatedActors < ActiveRecord::Migration[8.1]
  def change
    create_table :federated_actors do |t|
      t.string :actor_uri, null: false
      t.string :actor_type
      t.string :inbox_url, null: false
      t.string :shared_inbox_url
      t.string :username
      t.string :domain
      t.string :display_name
      t.string :avatar_url
      t.text :public_key
      t.jsonb :actor_data
      t.datetime :last_fetched_at

      t.timestamps
    end

    add_index :federated_actors, :actor_uri, unique: true
    add_index :federated_actors, :domain
  end
end

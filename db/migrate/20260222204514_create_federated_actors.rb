class CreateFederatedActors < ActiveRecord::Migration[8.1]
  def change
    create_table :federated_actors do |t|
      t.string :actor_uri
      t.string :username
      t.string :display_name
      t.string :avatar_url
      t.datetime :last_fetched_at

      t.timestamps
    end
  end
end

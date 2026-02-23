class AddKeypairToWebsteads < ActiveRecord::Migration[8.0]
  def change
    add_column :websteads, :private_key, :text
    add_column :websteads, :public_key, :text
  end
end

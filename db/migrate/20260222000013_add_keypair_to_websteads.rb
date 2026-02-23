class AddKeypairToWebsteads < ActiveRecord::Migration[8.0]
  def change
    add_column :websteads, :private_key_pem, :text
    add_column :websteads, :public_key_pem, :text
  end
end

class UpdateWebsteadKeys < ActiveRecord::Migration[8.1]
  def change
    rename_column :websteads, :private_key, :private_key_pem
    rename_column :websteads, :public_key, :public_key_pem
    add_column :websteads, :rotated_at, :datetime
  end
end

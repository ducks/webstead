class AddTenantCompoundIndexes < ActiveRecord::Migration[8.1]
  def change
    add_index :comments, [ :webstead_id, :post_id ], name: "index_comments_on_webstead_id_and_post_id"
    add_index :comments, [ :webstead_id, :parent_id ], name: "index_comments_on_webstead_id_and_parent_id"
  end
end

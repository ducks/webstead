class CreateWebsteads < ActiveRecord::Migration[8.0]
  def change
    create_table :websteads do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :subdomain, null: false, limit: 63
      t.string :custom_domain, limit: 253
      t.jsonb :settings, null: false, default: {}
      t.string :title
      t.text :description

      t.timestamps
    end

    add_index :websteads, :subdomain, unique: true
    add_index :websteads, :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
    add_index :websteads, :settings, using: :gin

    # CHECK constraints for format validation
    execute <<-SQL
      ALTER TABLE websteads
      ADD CONSTRAINT subdomain_format_check
      CHECK (subdomain ~ '^[a-z0-9][a-z0-9-]*[a-z0-9]$');
    SQL

    execute <<-SQL
      ALTER TABLE websteads
      ADD CONSTRAINT custom_domain_format_check
      CHECK (custom_domain IS NULL OR custom_domain ~ '^[a-z0-9][a-z0-9.-]*[a-z0-9]$');
    SQL
  end
end

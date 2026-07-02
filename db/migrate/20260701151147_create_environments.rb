class CreateEnvironments < ActiveRecord::Migration[6.1]
  def change
    create_table :environments do |t|
      t.string :name, null: false
      t.string :base_url, null: false
      t.text :token_ciphertext
      t.string :db_type, null: false, default: 'dedicated'
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :environments, :name, unique: true
  end
end

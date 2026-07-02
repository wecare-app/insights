class CreateClientCompanies < ActiveRecord::Migration[6.1]
  def change
    create_table :client_companies do |t|
      t.references :environment, null: false, foreign_key: true
      t.string :wecare_id, null: false
      t.string :name
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :client_companies, %i[environment_id wecare_id], unique: true
  end
end

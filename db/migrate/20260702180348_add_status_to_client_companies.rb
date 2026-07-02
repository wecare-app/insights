class AddStatusToClientCompanies < ActiveRecord::Migration[6.1]
  def change
    add_column :client_companies, :status, :string
  end
end

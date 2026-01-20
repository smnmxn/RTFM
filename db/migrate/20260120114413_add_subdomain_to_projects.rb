class AddSubdomainToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :subdomain, :string
    add_index :projects, :subdomain, unique: true, where: "subdomain IS NOT NULL"
  end
end

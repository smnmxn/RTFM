class AddProviderToProjectRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :project_repositories, :provider, :string, null: false, default: "github"
    add_index :project_repositories, :provider
  end
end

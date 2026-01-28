class AddBranchToProjectRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :project_repositories, :branch, :string
  end
end

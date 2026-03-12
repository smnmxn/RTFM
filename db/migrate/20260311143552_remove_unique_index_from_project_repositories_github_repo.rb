class RemoveUniqueIndexFromProjectRepositoriesGithubRepo < ActiveRecord::Migration[8.1]
  def change
    remove_index :project_repositories, :github_repo, unique: true
    add_index :project_repositories, :github_repo
  end
end

class AddGithubAppInstallationToProjects < ActiveRecord::Migration[8.1]
  def change
    add_reference :projects, :github_app_installation, foreign_key: true, null: true
    remove_column :projects, :webhook_secret, :string
    remove_column :projects, :github_webhook_id, :integer
  end
end

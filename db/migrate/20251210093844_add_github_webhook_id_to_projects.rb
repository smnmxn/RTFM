class AddGithubWebhookIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :github_webhook_id, :integer
  end
end

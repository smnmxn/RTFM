class AddWebhookUuidToProjectRepositories < ActiveRecord::Migration[8.1]
  def change
    add_column :project_repositories, :webhook_uuid, :string
  end
end

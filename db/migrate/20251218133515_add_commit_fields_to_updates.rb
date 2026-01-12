class AddCommitFieldsToUpdates < ActiveRecord::Migration[8.1]
  def change
    add_column :updates, :commit_sha, :string
    add_column :updates, :commit_url, :string
    add_column :updates, :source_type, :string, default: "pull_request"

    add_index :updates, :commit_sha
    add_index :updates, [ :project_id, :source_type ]
  end
end

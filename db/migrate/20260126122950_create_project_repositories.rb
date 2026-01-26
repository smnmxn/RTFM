class CreateProjectRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :project_repositories do |t|
      t.references :project, null: false, foreign_key: true
      t.string :github_repo, null: false
      t.bigint :github_installation_id, null: false
      t.boolean :is_primary, default: false, null: false

      t.timestamps
    end

    add_index :project_repositories, :github_repo, unique: true
    # Note: project_id index is automatically created by t.references
  end
end

class CreateArticleUpdateChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :article_update_checks do |t|
      t.references :project, null: false, foreign_key: true
      t.string :target_commit_sha, null: false
      t.string :base_commit_sha
      t.string :status, default: "pending", null: false
      t.json :results
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :article_update_checks, [ :project_id, :status ]
  end
end

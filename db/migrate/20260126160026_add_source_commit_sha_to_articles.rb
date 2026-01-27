class AddSourceCommitShaToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :source_commit_sha, :string
    add_index :articles, :source_commit_sha
  end
end

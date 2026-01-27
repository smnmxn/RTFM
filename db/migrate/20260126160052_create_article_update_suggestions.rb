class CreateArticleUpdateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :article_update_suggestions do |t|
      t.references :article_update_check, null: false, foreign_key: true
      t.references :article, foreign_key: true
      t.string :suggestion_type, null: false
      t.string :priority, default: "medium", null: false
      t.text :reason
      t.json :affected_files
      t.json :suggested_changes
      t.string :status, default: "pending", null: false
      t.timestamps
    end

    add_index :article_update_suggestions, [:article_update_check_id, :suggestion_type], name: "index_suggestions_on_check_and_type"
  end
end

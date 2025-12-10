class CreateUpdates < ActiveRecord::Migration[8.1]
  def change
    create_table :updates do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.text :social_snippet
      t.string :status, default: "draft", null: false
      t.integer :pull_request_number
      t.string :pull_request_url
      t.datetime :published_at

      t.timestamps
    end
  end
end

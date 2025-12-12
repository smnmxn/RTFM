class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.references :project, null: false, foreign_key: true
      t.references :recommendation, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content
      t.string :status, default: "draft", null: false
      t.string :generation_status, default: "pending", null: false
      t.datetime :published_at

      t.timestamps
    end
  end
end

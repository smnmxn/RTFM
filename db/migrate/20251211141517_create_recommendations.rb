class CreateRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendations do |t|
      t.references :project, null: false, foreign_key: true
      t.references :source_update, foreign_key: { to_table: :updates }
      t.string :title, null: false
      t.text :description
      t.text :justification
      t.string :status, default: "pending", null: false
      t.datetime :rejected_at

      t.timestamps
    end
  end
end

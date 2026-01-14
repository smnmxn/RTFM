class CreateStepImages < ActiveRecord::Migration[8.1]
  def change
    create_table :step_images do |t|
      t.references :article, null: false, foreign_key: true
      t.integer :step_index, null: false

      t.timestamps
    end

    add_index :step_images, [ :article_id, :step_index ], unique: true
  end
end

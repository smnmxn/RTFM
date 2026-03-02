class CreateProductEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :product_events do |t|
      t.integer :user_id, null: false
      t.integer :project_id
      t.string :event_name, null: false
      t.string :category, null: false
      t.json :properties
      t.datetime :created_at, null: false
    end

    add_index :product_events, [:event_name, :created_at]
    add_index :product_events, [:user_id, :created_at]
    add_index :product_events, [:project_id, :created_at]
    add_index :product_events, [:category, :created_at]

    add_foreign_key :product_events, :users
    add_foreign_key :product_events, :projects
  end
end

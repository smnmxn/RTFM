class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.string :section_type, null: false, default: "template"
      t.boolean :visible, default: true

      t.timestamps
    end

    add_index :sections, [ :project_id, :slug ], unique: true
    add_index :sections, [ :project_id, :position ]
  end
end

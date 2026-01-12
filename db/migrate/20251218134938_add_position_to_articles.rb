class AddPositionToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :position, :integer, default: 0
    add_index :articles, [ :section_id, :position ]
  end
end

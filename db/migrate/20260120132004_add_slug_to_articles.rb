class AddSlugToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :slug, :string
    add_index :articles, [:section_id, :slug], unique: true
  end
end

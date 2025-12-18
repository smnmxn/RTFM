class AddSectionToArticles < ActiveRecord::Migration[8.1]
  def change
    add_reference :articles, :section, foreign_key: true
  end
end

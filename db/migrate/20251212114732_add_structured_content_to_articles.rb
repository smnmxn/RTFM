class AddStructuredContentToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :structured_content, :json
  end
end

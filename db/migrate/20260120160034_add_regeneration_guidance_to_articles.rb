class AddRegenerationGuidanceToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :regeneration_guidance, :text
  end
end

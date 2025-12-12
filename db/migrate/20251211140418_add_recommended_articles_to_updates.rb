class AddRecommendedArticlesToUpdates < ActiveRecord::Migration[8.1]
  def change
    add_column :updates, :recommended_articles, :json
  end
end

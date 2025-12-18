class AddSectionToRecommendations < ActiveRecord::Migration[8.1]
  def change
    add_reference :recommendations, :section, foreign_key: true
  end
end

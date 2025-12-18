class AddRecommendationsStatusToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :recommendations_status, :string
    add_column :sections, :recommendations_started_at, :datetime
  end
end

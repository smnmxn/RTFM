class AddReviewStatusToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :review_status, :string, default: "unreviewed", null: false
    add_column :articles, :reviewed_at, :datetime
    add_index :articles, :review_status
  end
end

class AddPlanToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan, :string, default: "free", null: false
    add_column :users, :plan_status, :string, default: "active", null: false
    add_column :users, :trial_ends_at, :datetime
    add_index :users, :plan
  end
end

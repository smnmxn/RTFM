class AddServiceTierToClaudeUsages < ActiveRecord::Migration[8.1]
  def change
    add_column :claude_usages, :service_tier, :string
    add_index :claude_usages, :service_tier
  end
end

class AddAuthMethodToClaudeUsages < ActiveRecord::Migration[8.1]
  def change
    add_column :claude_usages, :auth_method, :string
  end
end

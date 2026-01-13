class AddUserContextToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :user_context, :json
  end
end

class AddBrandingToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :branding, :json
  end
end

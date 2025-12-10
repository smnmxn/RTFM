class AddProjectOverviewToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :project_overview, :text
  end
end

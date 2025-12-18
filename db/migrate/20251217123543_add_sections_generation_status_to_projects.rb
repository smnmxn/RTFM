class AddSectionsGenerationStatusToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :sections_generation_status, :string
    add_column :projects, :sections_generation_started_at, :datetime
  end
end

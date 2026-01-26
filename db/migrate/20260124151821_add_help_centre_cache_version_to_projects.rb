class AddHelpCentreCacheVersionToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :help_centre_cache_version, :integer, default: 0, null: false
  end
end

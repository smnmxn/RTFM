class AddAiSettingsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :ai_settings, :json
  end
end

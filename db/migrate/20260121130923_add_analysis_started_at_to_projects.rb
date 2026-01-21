class AddAnalysisStartedAtToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :analysis_started_at, :datetime
  end
end

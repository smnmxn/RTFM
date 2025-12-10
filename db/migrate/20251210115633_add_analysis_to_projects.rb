class AddAnalysisToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :analysis_summary, :text
    add_column :projects, :analysis_metadata, :json
    add_column :projects, :analysis_status, :string
    add_column :projects, :analyzed_at, :datetime
    add_column :projects, :analysis_commit_sha, :string
  end
end

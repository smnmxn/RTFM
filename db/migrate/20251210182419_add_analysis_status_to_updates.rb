class AddAnalysisStatusToUpdates < ActiveRecord::Migration[8.1]
  def change
    add_column :updates, :analysis_status, :string
  end
end

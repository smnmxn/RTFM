class AddStatusToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :status, :string, default: "accepted", null: false
    add_column :sections, :justification, :text
  end
end

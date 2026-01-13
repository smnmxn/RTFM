class AddIconToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :icon, :string
  end
end

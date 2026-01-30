class AddContactInfoToWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :waitlist_entries, :name, :string
    add_column :waitlist_entries, :company, :string
    add_column :waitlist_entries, :website, :string
  end
end

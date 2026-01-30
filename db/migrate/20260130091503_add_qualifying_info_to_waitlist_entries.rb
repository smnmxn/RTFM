class AddQualifyingInfoToWaitlistEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :waitlist_entries, :token, :string
    add_column :waitlist_entries, :platform_type, :string
    add_column :waitlist_entries, :repo_structure, :string
    add_column :waitlist_entries, :vcs_provider, :string
    add_column :waitlist_entries, :workflow, :string
    add_column :waitlist_entries, :user_base, :string
    add_column :waitlist_entries, :questions_completed_at, :datetime

    add_index :waitlist_entries, :token, unique: true
  end
end

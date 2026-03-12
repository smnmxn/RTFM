class ChangeUserIdentitiesUniqueIndex < ActiveRecord::Migration[8.1]
  def change
    # Allow multiple users to share the same provider+uid (e.g. same GitHub account)
    remove_index :user_identities, [:provider, :uid], unique: true
    add_index :user_identities, [:user_id, :provider, :uid], unique: true
    add_index :user_identities, [:provider, :uid]

    # Allow multiple users to have the same github_uid
    remove_index :users, :github_uid, unique: true
    add_index :users, :github_uid
  end
end

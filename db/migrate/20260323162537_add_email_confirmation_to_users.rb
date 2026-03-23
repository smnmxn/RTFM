class AddEmailConfirmationToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :email_confirmed_at, :datetime
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmation_sent_at, :datetime
    add_index :users, :confirmation_token, unique: true

    # Backfill existing users as confirmed so they aren't locked out
    User.update_all(email_confirmed_at: Time.current)
  end

  def down
    remove_index :users, :confirmation_token
    remove_column :users, :email_confirmed_at
    remove_column :users, :confirmation_token
    remove_column :users, :confirmation_sent_at
  end
end

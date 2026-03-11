class CreateUserIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :token
      t.string :refresh_token
      t.datetime :token_expires_at
      t.json :auth_data

      t.timestamps
    end
    add_index :user_identities, [:provider, :uid], unique: true
  end
end

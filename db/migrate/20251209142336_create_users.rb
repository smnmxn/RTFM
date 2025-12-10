class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :name
      t.string :github_uid
      t.string :github_username
      t.string :github_token

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :github_uid, unique: true
  end
end

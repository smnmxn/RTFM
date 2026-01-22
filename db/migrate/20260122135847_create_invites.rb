class CreateInvites < ActiveRecord::Migration[8.1]
  def change
    create_table :invites do |t|
      t.string :token, null: false
      t.string :email
      t.string :note
      t.references :user, null: true, foreign_key: true
      t.datetime :used_at

      t.timestamps
    end

    add_index :invites, :token, unique: true
  end
end

class CreateGithubAppInstallations < ActiveRecord::Migration[8.1]
  def change
    create_table :github_app_installations do |t|
      t.bigint :github_installation_id, null: false
      t.string :account_login, null: false
      t.string :account_type, null: false
      t.bigint :account_id, null: false
      t.datetime :suspended_at

      t.timestamps

      t.index :github_installation_id, unique: true
      t.index :account_login
    end
  end
end

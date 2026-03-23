class CreateBitbucketConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :bitbucket_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :workspace_slug, null: false
      t.string :workspace_name
      t.string :workspace_uuid
      t.string :access_token, null: false
      t.string :refresh_token, null: false
      t.datetime :token_expires_at, null: false
      t.string :scopes
      t.datetime :suspended_at

      t.timestamps
    end

    add_index :bitbucket_connections, [:user_id, :workspace_slug], unique: true
    add_index :bitbucket_connections, :workspace_slug
  end
end

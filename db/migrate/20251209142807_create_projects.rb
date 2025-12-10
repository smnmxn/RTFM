class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :slug
      t.string :github_repo
      t.string :webhook_secret

      t.timestamps
    end
    add_index :projects, :slug, unique: true
  end
end

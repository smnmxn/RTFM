class AddUserToGithubAppInstallations < ActiveRecord::Migration[8.1]
  def change
    add_reference :github_app_installations, :user, foreign_key: true
  end
end

class BackfillUserIdentities < ActiveRecord::Migration[8.1]
  def up
    User.where.not(github_uid: nil).find_each do |user|
      next if UserIdentity.exists?(user_id: user.id, provider: "github")

      UserIdentity.create!(
        user_id: user.id,
        provider: "github",
        uid: user.github_uid,
        token: user.github_token,
        auth_data: { username: user.github_username }
      )
    end
  end

  def down
    UserIdentity.where(provider: "github").delete_all
  end
end

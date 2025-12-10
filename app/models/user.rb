class User < ApplicationRecord
  has_many :projects, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :github_uid, uniqueness: true, allow_nil: true

  def self.find_or_create_from_omniauth(auth)
    user = find_by(github_uid: auth.uid)

    if user
      user.update!(
        github_token: auth.credentials.token,
        github_username: auth.info.nickname,
        name: auth.info.name,
        email: auth.info.email
      )
      user
    else
      create!(
        github_uid: auth.uid,
        github_token: auth.credentials.token,
        github_username: auth.info.nickname,
        name: auth.info.name,
        email: auth.info.email
      )
    end
  end
end

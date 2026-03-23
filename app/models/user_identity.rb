class UserIdentity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true, inclusion: { in: %w[github google_oauth2 apple bitbucket] }
  validates :uid, presence: true, uniqueness: { scope: [:user_id, :provider] }
end

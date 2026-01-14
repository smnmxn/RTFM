class GithubAppInstallation < ApplicationRecord
  belongs_to :user, optional: true
  has_many :projects, dependent: :nullify

  validates :github_installation_id, presence: true, uniqueness: true
  validates :account_login, presence: true
  validates :account_type, presence: true, inclusion: { in: %w[User Organization] }
  validates :account_id, presence: true

  scope :active, -> { where(suspended_at: nil) }
  scope :suspended, -> { where.not(suspended_at: nil) }
  scope :for_account, ->(login) { where(account_login: login) }

  def suspended?
    suspended_at.present?
  end

  def active?
    !suspended?
  end

  def client
    GithubAppService.client_for_installation(github_installation_id)
  end

  def repositories(page: 1, per_page: 30)
    client.list_app_installation_repositories(per_page: per_page, page: page)
  end
end

class ProjectRepository < ApplicationRecord
  belongs_to :project

  validates :github_repo, presence: true,
            format: { with: %r{\A[\w.-]+/[\w.-]+\z}, message: "must be in 'owner/repo' format" },
            uniqueness: { message: "is already connected to another project" }
  validates :github_installation_id, presence: true
  validates :provider, presence: true

  scope :primary, -> { where(is_primary: true) }

  # Provider-agnostic aliases
  alias_attribute :repo_identifier, :github_repo
  alias_attribute :vcs_installation_id, :github_installation_id

  # VCS adapter for this repository's provider
  def vcs_adapter
    Vcs::Provider.for(provider)
  end

  # Authenticated client via the adapter
  def vcs_client
    vcs_adapter.authenticate(github_installation_id)
  end

  def installation
    GithubAppInstallation.find_by(github_installation_id: github_installation_id)
  end

  # Legacy method — delegates through adapter for GitHub, kept for compatibility
  def client
    installation&.client
  end

  # Directory name for cloning (sanitized: owner/repo -> owner-repo)
  def clone_directory_name
    github_repo.gsub("/", "-")
  end

  # Get the repo owner from github_repo
  def repo_owner
    github_repo.split("/").first
  end

  # Get the repo name from github_repo
  def repo_name
    github_repo.split("/").last
  end
end

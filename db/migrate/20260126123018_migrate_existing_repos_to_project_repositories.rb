class MigrateExistingReposToProjectRepositories < ActiveRecord::Migration[8.1]
  def up
    # Migrate existing projects with real repos to the new ProjectRepository table
    execute <<-SQL
      INSERT INTO project_repositories (project_id, github_repo, github_installation_id, is_primary, created_at, updated_at)
      SELECT
        p.id,
        p.github_repo,
        gai.github_installation_id,
        true,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM projects p
      INNER JOIN github_app_installations gai ON gai.id = p.github_app_installation_id
      WHERE p.github_repo IS NOT NULL
        AND p.github_repo != 'placeholder/placeholder'
        AND p.github_app_installation_id IS NOT NULL
    SQL
  end

  def down
    execute "DELETE FROM project_repositories"
  end
end

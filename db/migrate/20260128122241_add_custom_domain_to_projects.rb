class AddCustomDomainToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :custom_domain, :string
    add_column :projects, :custom_domain_status, :string, default: "pending"
    add_column :projects, :custom_domain_cloudflare_id, :string
    add_column :projects, :custom_domain_verified_at, :datetime
    add_column :projects, :custom_domain_ssl_status, :string

    add_index :projects, :custom_domain, unique: true, where: "custom_domain IS NOT NULL"
  end
end

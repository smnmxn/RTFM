class AddWebsiteUrlToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :website_url, :string
  end
end

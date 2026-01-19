class AddRenderMetadataToStepImages < ActiveRecord::Migration[8.1]
  def change
    add_column :step_images, :render_metadata, :json
    add_column :step_images, :render_status, :string, default: "pending"
    add_column :step_images, :render_attempts, :integer, default: 0
  end
end

class AddSourceHtmlToStepImages < ActiveRecord::Migration[8.1]
  def change
    add_column :step_images, :source_html, :text
  end
end

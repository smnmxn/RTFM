class AddMetadataToPendingNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :pending_notifications, :metadata, :json
  end
end

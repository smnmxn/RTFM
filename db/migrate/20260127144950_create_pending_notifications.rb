class CreatePendingNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :pending_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :status, null: false
      t.string :message
      t.string :action_url

      t.timestamps
    end
  end
end

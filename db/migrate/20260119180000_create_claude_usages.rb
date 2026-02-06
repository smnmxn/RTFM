class CreateClaudeUsages < ActiveRecord::Migration[8.1]
  def change
    create_table :claude_usages do |t|
      t.references :project, null: true, foreign_key: true
      t.string :job_type, null: false
      t.string :session_id

      # Token counts
      t.integer :input_tokens, default: 0, null: false
      t.integer :output_tokens, default: 0, null: false
      t.integer :cache_creation_tokens, default: 0, null: false
      t.integer :cache_read_tokens, default: 0, null: false

      # Cost and timing
      t.decimal :cost_usd, precision: 10, scale: 6
      t.integer :duration_ms
      t.integer :num_turns

      # Context
      t.json :metadata
      t.boolean :success, default: true, null: false
      t.text :error_message

      t.timestamps

      t.index :job_type
      t.index :created_at
      t.index [ :project_id, :created_at ]
    end
  end
end

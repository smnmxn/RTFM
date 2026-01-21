class ClaudeUsage < ApplicationRecord
  belongs_to :project, optional: true

  # Validations
  validates :job_type, presence: true
  validates :input_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :output_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cache_creation_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :cache_read_tokens, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_project, ->(project) { where(project: project) }
  scope :for_job_type, ->(job_type) { where(job_type: job_type) }
  scope :for_service_tier, ->(tier) { where(service_tier: tier) }
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :recent, ->(limit = 100) { order(created_at: :desc).limit(limit) }

  # Class method to create from Claude CLI JSON output
  def self.from_claude_output(json_data, job_type:, project: nil, metadata: {}, success: true, error_message: nil)
    usage = json_data["usage"] || {}

    create!(
      project: project,
      job_type: job_type,
      session_id: json_data["session_id"],
      input_tokens: usage["input_tokens"] || 0,
      output_tokens: usage["output_tokens"] || 0,
      cache_creation_tokens: usage["cache_creation_input_tokens"] || 0,
      cache_read_tokens: usage["cache_read_input_tokens"] || 0,
      cost_usd: json_data["total_cost_usd"],
      duration_ms: json_data["duration_ms"],
      num_turns: json_data["num_turns"],
      service_tier: usage["service_tier"],
      metadata: metadata.presence,
      success: success,
      error_message: error_message
    )
  end

  # Instance methods
  def total_tokens
    input_tokens + output_tokens
  end

  # Class methods for aggregation
  def self.total_cost
    sum(:cost_usd)
  end

  def self.total_input_tokens
    sum(:input_tokens)
  end

  def self.total_output_tokens
    sum(:output_tokens)
  end

  def self.total_all_tokens
    total_input_tokens + total_output_tokens
  end
end

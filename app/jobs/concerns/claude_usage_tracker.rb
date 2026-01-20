# frozen_string_literal: true

module ClaudeUsageTracker
  extend ActiveSupport::Concern

  private

  def record_claude_usage(output_dir:, job_type:, project: nil, metadata: {}, success: true, error_message: nil, usage_filename: "usage.json")
    usage_path = File.join(output_dir, usage_filename)

    unless File.exist?(usage_path)
      Rails.logger.warn "[ClaudeUsageTracker] No usage file found at #{usage_path}"
      return nil
    end

    begin
      raw_content = File.read(usage_path)
      json_data = JSON.parse(raw_content)

      ClaudeUsage.from_claude_output(
        json_data,
        job_type: job_type,
        project: project,
        metadata: metadata,
        success: success,
        error_message: error_message
      )
    rescue JSON::ParserError => e
      Rails.logger.error "[ClaudeUsageTracker] Failed to parse usage JSON: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "[ClaudeUsageTracker] Error recording usage: #{e.message}"
      nil
    end
  end
end

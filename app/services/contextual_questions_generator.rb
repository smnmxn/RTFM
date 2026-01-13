require "net/http"
require "json"
require "uri"

class ContextualQuestionsGenerator
  ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
  MODEL = "claude-sonnet-4-20250514"
  MAX_TOKENS = 1024

  def initialize(project)
    @project = project
  end

  def generate
    return nil unless ENV["ANTHROPIC_API_KEY"].present?

    response = call_claude_api(build_prompt)
    parse_response(response)
  rescue StandardError => e
    Rails.logger.error "[ContextualQuestionsGenerator] Error: #{e.message}"
    nil
  end

  private

  def build_prompt
    analysis_metadata = @project.analysis_metadata || {}
    user_context = @project.user_context || {}

    <<~PROMPT
      Based on the following codebase analysis, generate 2-3 contextual questions to ask the user about their documentation needs.

      ## Codebase Analysis
      - Project: #{@project.name}
      - Overview: #{@project.project_overview}
      - Tech Stack: #{analysis_metadata['tech_stack']&.join(', ') || 'Unknown'}
      - Components: #{analysis_metadata['components']&.join(', ') || 'Unknown'}
      - Key Patterns: #{analysis_metadata['key_patterns']&.join(', ') || 'Unknown'}

      ## User Context (from previous questions)
      - Target Audience: #{user_context['target_audience'] || 'Not specified'}
      - Industry: #{user_context['industry'] || 'Not specified'}
      - Documentation Goals: #{user_context['documentation_goals']&.join(', ') || 'Not specified'}

      ## Requirements
      Generate questions that:
      1. Help prioritize which features/components to document first
      2. Identify user pain points or confusing areas that code can't reveal
      3. Are SPECIFIC to THIS codebase - reference actual components/tech found
      4. Have 3-4 answer options each (derived from analysis)

      ## Response Format
      Return ONLY valid JSON (no markdown, no explanation) in this exact format:
      {
        "questions": [
          {
            "id": "q1",
            "type": "prioritization",
            "question": "Your question here?",
            "context": "Brief explanation of why asking (10-15 words)",
            "options": [
              {"value": "option_key", "label": "Human readable label"}
            ],
            "multi_select": true
          }
        ]
      }

      Types: "prioritization" (which to focus on) or "gap_filling" (what's confusing/missing)
      multi_select: true for checkboxes, false for radio buttons
    PROMPT
  end

  def call_claude_api(prompt)
    uri = URI(ANTHROPIC_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["x-api-key"] = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"

    request.body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [
        { role: "user", content: prompt }
      ]
    }.to_json

    response = http.request(request)

    if response.code == "200"
      JSON.parse(response.body)
    else
      Rails.logger.error "[ContextualQuestionsGenerator] API error: #{response.code} - #{response.body}"
      nil
    end
  end

  def parse_response(response)
    return nil unless response

    content = response.dig("content", 0, "text")
    return nil unless content

    # Clean up the response (remove markdown fences if present)
    clean_json = content
      .gsub(/\A\s*```json\s*/i, "")
      .gsub(/\s*```\s*\z/, "")
      .strip

    parsed = JSON.parse(clean_json)
    questions = parsed["questions"]

    # Validate structure
    return nil unless questions.is_a?(Array) && questions.any?

    # Ensure each question has required fields
    questions.each_with_index do |q, i|
      q["id"] ||= "q#{i + 1}"
      q["type"] ||= "prioritization"
      q["multi_select"] = q["multi_select"] != false
    end

    questions
  rescue JSON::ParserError => e
    Rails.logger.error "[ContextualQuestionsGenerator] JSON parse error: #{e.message}"
    Rails.logger.error "[ContextualQuestionsGenerator] Raw content: #{content&.first(200)}"
    nil
  end
end

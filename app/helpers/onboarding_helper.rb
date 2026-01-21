# frozen_string_literal: true

module OnboardingHelper
  ANALYSIS_QUESTIONS = {
    target_audience: {
      question: "Who's reading these docs?",
      options: {
        "developers" => "Developers / Engineers",
        "product_managers" => "Product Managers / Business Users",
        "end_users" => "End Users / Customers",
        "internal" => "Internal Team Members"
      }
    },
    industry: {
      question: "What kind of product is this?",
      options: {
        "devtools" => "Developer Tools / Infrastructure",
        "saas" => "SaaS / Business Software",
        "ecommerce" => "E-commerce / Marketplace",
        "fintech" => "Fintech / Payments",
        "healthcare" => "Healthcare / Life Sciences",
        "other" => "Other"
      }
    },
    documentation_goals: {
      question: "What should the docs help with?",
      options: {
        "onboarding" => "Onboarding new users",
        "support" => "Reducing support tickets",
        "api_reference" => "API / Technical reference",
        "features" => "Feature explanations",
        "compliance" => "Compliance / Security"
      }
    },
    tone_preference: {
      question: "What tone feels right?",
      options: {
        "technical" => "Technical & precise",
        "friendly" => "Friendly & conversational",
        "minimal" => "Minimal & scannable",
        "formal" => "Formal & professional"
      }
    },
    product_stage: {
      question: "Where's the product at?",
      options: {
        "early" => "Early stage / MVP",
        "growing" => "Growing / Scaling",
        "mature" => "Mature / Enterprise",
        "internal" => "Internal tool"
      }
    }
  }.freeze

  # Build an array of completed analysis questions for display
  def completed_analysis_questions(project)
    ANALYSIS_QUESTIONS.map do |key, config|
      value = project.send(key)
      answer = if value.blank?
        nil
      elsif value.is_a?(Array)
        # Multi-select (documentation_goals)
        value.map { |v| config[:options][v] }.compact.join(", ")
      else
        config[:options][value]
      end

      {
        question: config[:question],
        answer: answer,
        skipped: value.blank?
      }
    end
  end

  # Build an array of completed contextual questions for display
  def completed_contextual_questions(project)
    questions = project.contextual_questions || []
    answers = project.user_context&.dig("contextual_answers") || {}

    questions.map do |q|
      answer_value = answers[q["id"]]
      answer = if answer_value.blank?
        nil
      elsif answer_value.is_a?(Array)
        # Multi-select - map values to labels
        answer_value.map do |v|
          option = q["options"]&.find { |o| o["value"] == v }
          option ? option["label"] : v
        end.join(", ")
      elsif q["input_type"] == "text"
        # Free text answer
        answer_value
      else
        # Single select - find the label
        option = q["options"]&.find { |o| o["value"] == answer_value }
        option ? option["label"] : answer_value
      end

      {
        question: q["question"],
        answer: answer,
        skipped: answer_value.blank?
      }
    end
  end
end

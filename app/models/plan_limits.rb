module PlanLimits
  LIMITS = {
    "free" => {
      projects: 1,
      articles: 10,
      team_members: 1,
      ai_answers_per_month: 100,
      custom_domain: false,
      custom_branding: false,
      analytics: false,
      remove_badge: false
    }.freeze,
    "pro" => {
      projects: Float::INFINITY,
      articles: Float::INFINITY,
      team_members: 10,
      ai_answers_per_month: Float::INFINITY,
      custom_domain: true,
      custom_branding: true,
      analytics: true,
      remove_badge: true
    }.freeze,
    "enterprise" => {
      projects: Float::INFINITY,
      articles: Float::INFINITY,
      team_members: Float::INFINITY,
      ai_answers_per_month: Float::INFINITY,
      custom_domain: true,
      custom_branding: true,
      analytics: true,
      remove_badge: true
    }.freeze
  }.freeze

  def self.for(plan)
    LIMITS.fetch(plan, LIMITS["free"])
  end
end

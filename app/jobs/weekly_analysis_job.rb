class WeeklyAnalysisJob < ApplicationJob
  queue_as :analysis

  def perform
    projects = Project.where.not(onboarding_step: ONBOARDING_STEPS_IN_PROGRESS)
    projects.find_each do |project|
      next unless project.update_strategy_value == "weekly"
      next unless project.primary_github_repo.present?

      analyze_recent_prs(project)
    rescue => e
      Rails.logger.error "[WeeklyAnalysis] Error processing project #{project.id}: #{e.message}"
    end
  end

  private

  ONBOARDING_STEPS_IN_PROGRESS = Project::ONBOARDING_STEPS - [ "complete" ]

  def analyze_recent_prs(project)
    client = project.github_client
    return unless client

    repo = project.primary_github_repo
    since = project.updates.maximum(:created_at) || 1.week.ago

    # Fetch recently merged PRs
    prs = client.pull_requests(repo, state: "closed", sort: "updated", direction: "desc")
    merged_prs = prs.select { |pr| pr.merged_at && pr.merged_at > since }

    merged_prs.each do |pr|
      # Skip if already analyzed
      next if project.updates.exists?(pull_request_number: pr.number)

      AnalyzePullRequestJob.perform_later(
        project_id: project.id,
        pull_request_number: pr.number,
        pull_request_url: pr.html_url,
        pull_request_title: pr.title,
        pull_request_body: pr.body.to_s,
        merge_commit_sha: pr.merge_commit_sha,
        source_repo: repo
      )
    end
  end
end

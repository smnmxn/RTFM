require "octokit"

class AnalyzePullRequestJob < ApplicationJob
  queue_as :default

  retry_on Octokit::Error, wait: :polynomially_longer, attempts: 3

  def perform(project_id:, pull_request_number:, pull_request_url:, pull_request_title:, pull_request_body:)
    project = Project.find_by(id: project_id)
    return unless project

    user = project.user
    return unless user&.github_token.present?

    client = build_github_client(user.github_token)

    diff = client.pull_request(
      project.github_repo,
      pull_request_number,
      accept: "application/vnd.github.v3.diff"
    )

    project.updates.create!(
      title: pull_request_title.presence || "PR ##{pull_request_number}",
      content: placeholder_content(pull_request_number, pull_request_title, pull_request_body, diff),
      social_snippet: "New update from PR ##{pull_request_number}",
      pull_request_number: pull_request_number,
      pull_request_url: pull_request_url,
      status: :draft
    )

    Rails.logger.info "[AnalyzePullRequestJob] Created draft update for PR ##{pull_request_number} in project #{project.id}"
  end

  private

  def build_github_client(access_token)
    Octokit::Client.new(access_token: access_token)
  end

  def placeholder_content(pr_number, title, body, diff)
    lines_changed = diff.to_s.lines.count { |line| line.start_with?("+", "-") && !line.start_with?("+++", "---") }

    <<~CONTENT
      ## #{title || "Pull Request ##{pr_number}"}

      #{body.presence || "_No description provided._"}

      ---

      **This update was automatically generated from a merged pull request.**

      - Lines changed: ~#{lines_changed}

      _AI-generated summary coming in Phase 3._
    CONTENT
  end
end

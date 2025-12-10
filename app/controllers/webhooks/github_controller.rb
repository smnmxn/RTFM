module Webhooks
  class GithubController < ApplicationController
    skip_before_action :require_authentication
    skip_forgery_protection

    def create
      payload = request.body.read
      signature = request.headers["X-Hub-Signature-256"]
      event_type = request.headers["X-GitHub-Event"]

      unless event_type == "pull_request"
        head :ok
        return
      end

      begin
        data = JSON.parse(payload)
      rescue JSON::ParserError
        head :bad_request
        return
      end

      repo_full_name = data.dig("repository", "full_name")

      project = Project.find_by(github_repo: repo_full_name)
      unless project
        Rails.logger.warn "[Webhook] No project found for repo: #{repo_full_name}"
        head :not_found
        return
      end

      unless project.verify_webhook_signature(payload, signature)
        Rails.logger.warn "[Webhook] Invalid signature for project: #{project.id}"
        head :unauthorized
        return
      end

      action = data["action"]
      pull_request = data["pull_request"]

      unless action == "closed" && pull_request&.dig("merged")
        head :ok
        return
      end

      AnalyzePullRequestJob.perform_later(
        project_id: project.id,
        pull_request_number: pull_request["number"],
        pull_request_url: pull_request["html_url"],
        pull_request_title: pull_request["title"],
        pull_request_body: pull_request["body"]
      )

      head :accepted
    end
  end
end

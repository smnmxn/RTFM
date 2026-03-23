module Webhooks
  class BitbucketController < ApplicationController
    skip_before_action :require_authentication
    skip_forgery_protection

    def create
      payload = request.body.read
      signature = request.headers["X-Hub-Signature"]
      event_type = request.headers["X-Event-Key"]

      # Verify signature using webhook secret
      adapter = Vcs::Provider.for(:bitbucket)
      unless adapter.verify_webhook(payload, signature)
        Rails.logger.warn "[Webhook] Invalid Bitbucket signature"
        head :unauthorized
        return
      end

      begin
        handler = Vcs::Bitbucket::WebhookHandler.new(payload: payload, event_type: event_type)
        event = handler.process
      rescue JSON::ParserError
        head :bad_request
        return
      end

      case event[:action]
      when :pull_request_merged
        handle_pull_request_merged(event)
      when :push
        handle_push(event)
      else
        head :ok
      end
    end

    private

    def handle_pull_request_merged(event)
      repo_full_name = event[:repo]

      project_repo = ProjectRepository.find_by(github_repo: repo_full_name, provider: "bitbucket")
      project = project_repo&.project

      unless project
        Rails.logger.warn "[Webhook] No project found for Bitbucket repo: #{repo_full_name}"
        head :not_found
        return
      end

      unless project.update_strategy_value == "pull_request"
        Rails.logger.info "[Webhook] Skipping auto-analysis for #{repo_full_name} (strategy: #{project.update_strategy_value})"
        head :ok
        return
      end

      # Filter by tracked branch if configured
      if project_repo.branch.present?
        unless event[:target_branch] == project_repo.branch
          Rails.logger.info "[Webhook] Skipping PR for #{repo_full_name} (target: #{event[:target_branch]}, tracked: #{project_repo.branch})"
          head :ok
          return
        end
      end

      AnalyzePullRequestJob.perform_later(
        project_id: project.id,
        pull_request_number: event[:pr_number],
        pull_request_url: event[:pr_url],
        pull_request_title: event[:pr_title],
        pull_request_body: event[:pr_body],
        merge_commit_sha: event[:merge_commit_sha],
        source_repo: repo_full_name
      )

      head :accepted
    end

    def handle_push(event)
      # Push events can be handled for commit-based update strategy
      # For now, just acknowledge receipt
      Rails.logger.info "[Webhook] Received Bitbucket push event for #{event[:repo]} with #{event[:commits]&.size || 0} commits"
      head :ok
    end
  end
end

module Webhooks
  class GithubController < ApplicationController
    skip_before_action :require_authentication
    skip_forgery_protection

    def create
      payload = request.body.read
      signature = request.headers["X-Hub-Signature-256"]
      event_type = request.headers["X-GitHub-Event"]

      # Verify signature using app-level webhook secret
      adapter = Vcs::Provider.for(:github)
      unless adapter.verify_webhook(payload, signature)
        Rails.logger.warn "[Webhook] Invalid signature"
        head :unauthorized
        return
      end

      begin
        handler = Vcs::Github::WebhookHandler.new(payload: payload, event_type: event_type)
        event = handler.process
      rescue JSON::ParserError
        head :bad_request
        return
      end

      case event[:action]
      when :installation_created
        handle_installation_created(event)
      when :installation_deleted
        handle_installation_deleted(event)
      when :installation_suspended
        handle_installation_suspended(event)
      when :installation_unsuspended
        handle_installation_unsuspended(event)
      when :pull_request_merged
        handle_pull_request_merged(event)
      else
        head :ok
      end
    end

    private

    def handle_installation_created(event)
      GithubAppInstallation.find_or_create_by!(
        github_installation_id: event[:installation_id]
      ) do |i|
        i.account_login = event[:account_login]
        i.account_type = event[:account_type]
        i.account_id = event[:account_id]
        i.suspended_at = nil
      end
      Rails.logger.info "[Webhook] GitHub App installed for #{event[:account_login]}"
      head :ok
    end

    def handle_installation_deleted(event)
      record = GithubAppInstallation.find_by(github_installation_id: event[:installation_id])
      if record
        record.projects.update_all(github_app_installation_id: nil)
        record.destroy
        Rails.logger.info "[Webhook] GitHub App uninstalled for #{event[:account_login]}"
      end
      head :ok
    end

    def handle_installation_suspended(event)
      record = GithubAppInstallation.find_by(github_installation_id: event[:installation_id])
      record&.update!(suspended_at: Time.current)
      Rails.logger.info "[Webhook] GitHub App suspended for #{event[:account_login]}"
      head :ok
    end

    def handle_installation_unsuspended(event)
      record = GithubAppInstallation.find_by(github_installation_id: event[:installation_id])
      record&.update!(suspended_at: nil)
      Rails.logger.info "[Webhook] GitHub App unsuspended for #{event[:account_login]}"
      head :ok
    end

    def handle_pull_request_merged(event)
      repo_full_name = event[:repo]

      # Look up project through ProjectRepository join table first, fall back to legacy
      project_repo = ProjectRepository.find_by(github_repo: repo_full_name)
      project = project_repo&.project || Project.find_by(github_repo: repo_full_name)

      unless project
        Rails.logger.warn "[Webhook] No project found for repo: #{repo_full_name}"
        head :not_found
        return
      end

      unless project.update_strategy_value == "pull_request"
        Rails.logger.info "[Webhook] Skipping auto-analysis for #{repo_full_name} (strategy: #{project.update_strategy_value})"
        head :ok
        return
      end

      # Filter by tracked branch if configured
      if project_repo&.branch.present?
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
  end
end

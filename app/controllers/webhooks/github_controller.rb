module Webhooks
  class GithubController < ApplicationController
    skip_before_action :require_authentication
    skip_forgery_protection

    def create
      payload = request.body.read
      signature = request.headers["X-Hub-Signature-256"]
      event_type = request.headers["X-GitHub-Event"]

      # Verify signature using app-level webhook secret
      unless GithubAppService.new.verify_webhook_signature(payload, signature)
        Rails.logger.warn "[Webhook] Invalid signature"
        head :unauthorized
        return
      end

      begin
        data = JSON.parse(payload)
      rescue JSON::ParserError
        head :bad_request
        return
      end

      case event_type
      when "installation"
        handle_installation_event(data)
      when "pull_request"
        handle_pull_request_event(data)
      else
        head :ok
      end
    end

    private

    def handle_installation_event(data)
      action = data["action"]
      installation = data["installation"]

      case action
      when "created"
        GithubAppInstallation.find_or_create_by!(
          github_installation_id: installation["id"]
        ) do |i|
          i.account_login = installation.dig("account", "login")
          i.account_type = installation.dig("account", "type")
          i.account_id = installation.dig("account", "id")
          i.suspended_at = nil
        end
        Rails.logger.info "[Webhook] GitHub App installed for #{installation.dig('account', 'login')}"

      when "deleted"
        record = GithubAppInstallation.find_by(github_installation_id: installation["id"])
        if record
          record.projects.update_all(github_app_installation_id: nil)
          record.destroy
          Rails.logger.info "[Webhook] GitHub App uninstalled for #{installation.dig('account', 'login')}"
        end

      when "suspend"
        record = GithubAppInstallation.find_by(github_installation_id: installation["id"])
        record&.update!(suspended_at: Time.current)
        Rails.logger.info "[Webhook] GitHub App suspended for #{installation.dig('account', 'login')}"

      when "unsuspend"
        record = GithubAppInstallation.find_by(github_installation_id: installation["id"])
        record&.update!(suspended_at: nil)
        Rails.logger.info "[Webhook] GitHub App unsuspended for #{installation.dig('account', 'login')}"
      end

      head :ok
    end

    def handle_pull_request_event(data)
      action = data["action"]
      pull_request = data["pull_request"]

      unless action == "closed" && pull_request&.dig("merged")
        head :ok
        return
      end

      repo_full_name = data.dig("repository", "full_name")

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

      AnalyzePullRequestJob.perform_later(
        project_id: project.id,
        pull_request_number: pull_request["number"],
        pull_request_url: pull_request["html_url"],
        pull_request_title: pull_request["title"],
        pull_request_body: pull_request["body"],
        source_repo: repo_full_name
      )

      head :accepted
    end
  end
end

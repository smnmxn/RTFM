module Onboarding
  class ProjectsController < ApplicationController
    layout "onboarding"

    before_action :set_project, except: [ :new, :create ]
    before_action :ensure_onboarding_active, except: [ :new, :create ]
    before_action :ensure_correct_step, except: [ :new, :create ]

    # Step 0: Start onboarding - auto-creates project and goes to repository selection
    def new
      # If user already has projects, they don't need onboarding for first project
      unless current_user.needs_onboarding? || current_user.onboarding_in_progress?
        redirect_to dashboard_path
        return
      end

      # If there's already an onboarding in progress, resume it
      if current_user.onboarding_in_progress?
        project = current_user.current_onboarding_project
        redirect_to send("#{project.onboarding_step}_onboarding_project_path", project)
        return
      end

      # Auto-create project and start onboarding immediately
      create_and_start_onboarding
    end

    def create
      create_and_start_onboarding
    end

    # Step 1: Connect Repository
    def repository
      @repositories = [] # Loaded via Turbo Frame
    end

    def connect
      repo_full_name = params[:github_repo]
      repo_name = repo_full_name&.split("/")&.last

      @project.assign_attributes(
        name: repo_name&.titleize&.tr("-", " "),
        github_repo: repo_full_name,
        slug: repo_name&.parameterize
      )

      # Create webhook
      webhook_service = GithubWebhookService.new(current_user)
      webhook_url = build_webhook_url

      result = webhook_service.create(
        repo_full_name: repo_full_name,
        webhook_secret: @project.webhook_secret,
        webhook_url: webhook_url
      )

      if result.success? || result.error == :webhook_exists
        @project.github_webhook_id = result.webhook_id if result.success?
        @project.save!
        @project.advance_onboarding!("analyze")
        redirect_to analyze_onboarding_project_path(@project)
      else
        redirect_to repository_onboarding_project_path(@project),
          alert: webhook_error_message(result.error, repo_full_name)
      end
    end

    # Step 2: Analyze Codebase
    def analyze
      # Auto-start analysis if not already running
      if @project.analysis_status.nil? || @project.analysis_status.blank?
        @project.update!(analysis_status: "pending")
        AnalyzeCodebaseJob.perform_later(@project.id)
      end
    end

    def start_analysis
      unless @project.analysis_status == "running"
        @project.update!(analysis_status: "pending")
        AnalyzeCodebaseJob.perform_later(@project.id)
      end
      redirect_to analyze_onboarding_project_path(@project)
    end

    def save_context
      current_context = @project.user_context || {}
      @project.update!(user_context: current_context.merge(context_params.to_h))
      head :ok
    end

    # Step 3: Review Sections
    def sections
      @pending_sections = @project.sections.pending.ordered
      @accepted_sections = @project.sections.accepted.ordered
    end

    def complete_sections
      if @project.sections.pending.any?
        redirect_to sections_onboarding_project_path(@project),
          alert: "Please review all section suggestions before continuing."
        return
      end

      # Trigger recommendation generation for any sections that haven't been started yet
      # (Most should already be running since they're kicked off in sections#accept)
      @project.sections.accepted.where(recommendations_status: nil).find_each do |section|
        section.update!(
          recommendations_status: "running",
          recommendations_started_at: Time.current
        )
        GenerateSectionRecommendationsJob.perform_later(
          project_id: @project.id,
          section_id: section.id
        )
      end

      # Complete onboarding and redirect to inbox
      @project.complete_onboarding!
      redirect_to project_path(@project), notice: "Recommendations are being generated and will appear in your inbox."
    end

    private

    def set_project
      @project = current_user.projects.find(params[:id])
    end

    def create_and_start_onboarding
      @project = current_user.projects.build(
        name: "New Project",
        onboarding_step: "repository",
        onboarding_started_at: Time.current
      )
      # Generate temporary values that will be replaced in step 1
      @project.slug = "project-#{SecureRandom.hex(4)}"
      @project.github_repo = "placeholder/placeholder"

      # Skip validations for the placeholder values
      if @project.save(validate: false)
        redirect_to repository_onboarding_project_path(@project)
      else
        redirect_to dashboard_path, alert: "Could not start onboarding"
      end
    end

    def ensure_onboarding_active
      unless @project.in_onboarding?
        redirect_to project_path(@project)
      end
    end

    def ensure_correct_step
      return if request.post? # Allow POST actions for current step

      current_action = action_name.to_s
      expected_step = @project.onboarding_step

      # Map action names to step names
      action_to_step = {
        "repository" => "repository",
        "analyze" => "analyze",
        "sections" => "sections"
      }

      return unless action_to_step.key?(current_action)
      return if current_action == expected_step

      # Redirect to correct step
      redirect_to send("#{expected_step}_onboarding_project_path", @project)
    end

    def build_webhook_url
      if ENV["HOST_URL"].present?
        "#{ENV['HOST_URL']}/webhooks/github"
      else
        webhooks_github_url(protocol: "https")
      end
    end

    def webhook_error_message(error, repo_full_name)
      case error
      when :no_admin_access
        "You need admin access to #{repo_full_name} to create webhooks."
      when :repo_not_found
        "Repository not found. It may have been deleted or made private."
      else
        "Failed to connect repository: #{error}"
      end
    end

    def context_params
      permitted = params.require(:context).permit(
        :target_audience,
        :industry,
        :tone_preference,
        :product_stage,
        documentation_goals: [],
        contextual_answers: {}
      )

      # Convert contextual_answers to a proper hash if present
      if params[:context][:contextual_answers].present?
        permitted[:contextual_answers] = params[:context][:contextual_answers].to_unsafe_h
      end

      permitted
    end
  end
end

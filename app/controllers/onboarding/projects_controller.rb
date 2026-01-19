module Onboarding
  class ProjectsController < ApplicationController
    layout "onboarding"

    before_action :set_project, except: [ :new, :create ]
    before_action :ensure_onboarding_active, except: [ :new, :create ]
    before_action :ensure_correct_step, except: [ :new, :create ]

    # Step 0: Start onboarding - auto-creates project and goes to repository selection
    def new
      # If there's already an onboarding in progress, resume it
      if current_user.onboarding_in_progress?
        project = current_user.current_onboarding_project
        if Project::ONBOARDING_STEPS.include?(project.onboarding_step)
          redirect_to send("#{project.onboarding_step}_onboarding_project_path", project)
        else
          # Invalid step - complete onboarding and go to project
          project.complete_onboarding!
          redirect_to project_path(project)
        end
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
      installation_id = params[:installation_id]
      repo_name = repo_full_name&.split("/")&.last

      # Find the installation
      installation = GithubAppInstallation.find_by(github_installation_id: installation_id)
      unless installation
        redirect_to repository_onboarding_project_path(@project),
          alert: "GitHub App installation not found. Please install the app first."
        return
      end

      @project.assign_attributes(
        name: repo_name&.titleize&.tr("-", " "),
        github_repo: repo_full_name,
        slug: repo_name&.parameterize,
        github_app_installation: installation
      )

      @project.save!
      @project.advance_onboarding!("analyze")
      redirect_to analyze_onboarding_project_path(@project)
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

    def retry_sections
      unless @project.sections_generation_status == "running"
        @project.update!(
          sections_generation_status: "pending",
          sections_generation_started_at: Time.current
        )
        SuggestSectionsJob.perform_later(project_id: @project.id)
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

      # Mark all accepted sections as running
      # Using a single consolidated job prevents duplicate recommendations across sections
      @project.sections.accepted.update_all(
        recommendations_status: "running",
        recommendations_started_at: Time.current
      )

      # Single consolidated job generates recommendations for ALL accepted sections
      # This allows Claude to see all sections at once and assign each recommendation
      # to exactly one section, preventing duplicates
      GenerateAllRecommendationsJob.perform_later(project_id: @project.id)

      # Advance to generating step (will redirect to inbox when complete)
      @project.advance_onboarding!("generating")
      redirect_to generating_onboarding_project_path(@project)
    end

    # Step 4: Generating Recommendations (loading state)
    def generating
      # If all recommendations are generated, complete onboarding and redirect
      if @project.all_recommendations_generated?
        @project.complete_onboarding!
        redirect_to project_path(@project), notice: "Your help centre is ready!"
        return
      end

      @progress = @project.recommendations_generation_progress
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

      # Handle invalid steps
      unless Project::ONBOARDING_STEPS.include?(expected_step)
        @project.complete_onboarding!
        redirect_to project_path(@project)
        return
      end

      # Map action names to step names
      action_to_step = {
        "repository" => "repository",
        "analyze" => "analyze",
        "sections" => "sections",
        "generating" => "generating"
      }

      return unless action_to_step.key?(current_action)
      return if current_action == expected_step

      # Redirect to correct step
      redirect_to send("#{expected_step}_onboarding_project_path", @project)
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

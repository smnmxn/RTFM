module Onboarding
  class ProjectsController < ApplicationController
    layout "onboarding"

    before_action :set_project, except: [ :new, :create ]
    before_action :ensure_onboarding_active, except: [ :new, :create ]
    before_action :ensure_correct_step, except: [ :new, :create ]

    # Step 0: Show form for project name and subdomain
    def new
      # Clean up any incomplete onboarding projects so user starts fresh
      current_user.projects.onboarding_incomplete.destroy_all

      @project = Project.new
    end

    def create
      @project = current_user.projects.build(basics_params)
      @project.onboarding_step = "repository"
      @project.onboarding_started_at = Time.current
      # Use subdomain as slug, or generate from name
      @project.slug = @project.subdomain.presence || @project.name.parameterize
      # Placeholder repo until they select one
      @project.github_repo = "placeholder/placeholder"

      if @project.save(validate: false)
        redirect_to repository_onboarding_project_path(@project)
      else
        render :new, status: :unprocessable_entity
      end
    end

    # Step 1: Edit project basics (name and subdomain)
    def basics
    end

    def update_basics
      if @project.update(basics_params)
        # Update slug to match subdomain if provided
        new_slug = @project.subdomain.presence || @project.name.parameterize
        @project.update_column(:slug, new_slug) if new_slug != @project.slug

        @project.advance_onboarding!("repository")
        redirect_to repository_onboarding_project_path(@project)
      else
        render :basics, status: :unprocessable_entity
      end
    end

    # Step 2: Connect Repository
    def repository
      @repositories = [] # Loaded via Turbo Frame
    end

    def connect
      repo_full_name = params[:github_repo]
      installation_id = params[:installation_id]

      # Find the installation
      installation = GithubAppInstallation.find_by(github_installation_id: installation_id)
      unless installation
        redirect_to repository_onboarding_project_path(@project),
          alert: "GitHub App installation not found. Please install the app first."
        return
      end

      # Only update github_repo and installation - preserve user's name and subdomain
      @project.assign_attributes(
        github_repo: repo_full_name,
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
        @project.update!(
          analysis_status: "pending",
          analysis_started_at: Time.current
        )
        AnalyzeCodebaseJob.perform_later(@project.id)
      end
    end

    def start_analysis
      unless @project.analysis_status == "running"
        @project.update!(
          analysis_status: "pending",
          analysis_started_at: Time.current
        )
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
      # Use update_column to avoid triggering after_update_commit callbacks
      # This prevents broadcast_refreshes from being called, which would
      # cause a race condition with the analysis job and make questions disappear
      @project.update_column(:user_context, current_context.merge(context_params.to_h))
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
      @project = current_user.projects.find_by(slug: params[:slug])
      unless @project
        redirect_to projects_path, alert: "Project not found."
      end
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
        redirect_to projects_path, alert: "Could not start onboarding"
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
        "basics" => "basics",
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

    def basics_params
      params.require(:project).permit(:name, :subdomain)
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

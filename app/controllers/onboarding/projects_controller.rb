module Onboarding
  class ProjectsController < ApplicationController
    layout "onboarding"

    before_action :set_project, except: [ :new, :create ]
    before_action :ensure_onboarding_active, except: [ :new, :create ]
    before_action :ensure_correct_step, except: [ :new, :create ]

    # Step 0: Landing page to start onboarding
    def new
      # Clean up any incomplete onboarding projects so user starts fresh
      current_user.projects.onboarding_incomplete.destroy_all

      @project = Project.new
    end

    def create
      # Create a bare project with temporary values — name/subdomain collected in setup step
      @project = current_user.projects.build(
        name: "New Project",
        onboarding_step: "repository",
        onboarding_started_at: Time.current
      )
      @project.slug = "project-#{SecureRandom.hex(4)}"
      @project.github_repo = "placeholder/placeholder"

      if @project.save(validate: false)
        redirect_to repository_onboarding_project_path(@project)
      else
        redirect_to projects_path, alert: "Could not start onboarding"
      end
    end

    # Step 1: Connect Repository
    def repository
      @repositories = [] # Loaded via Turbo Frame
    end

    def connect
      Rails.logger.info "[Onboarding::ProjectsController#connect] Raw params[:repositories]: #{params[:repositories].inspect}"
      repositories_params = params[:repositories]&.to_unsafe_h&.values || []
      Rails.logger.info "[Onboarding::ProjectsController#connect] Parsed repositories_params: #{repositories_params.inspect}"

      # Handle legacy single-repo format for backwards compatibility
      if repositories_params.empty? && params[:github_repo].present?
        repositories_params = [{ "github_repo" => params[:github_repo], "installation_id" => params[:installation_id], "selected" => "1" }]
        Rails.logger.info "[Onboarding::ProjectsController#connect] Using legacy format: #{repositories_params.inspect}"
      end

      # Filter to only selected repositories
      selected_repos = repositories_params.select { |r| r["selected"] == "1" }
      Rails.logger.info "[Onboarding::ProjectsController#connect] Selected repos: #{selected_repos.inspect}"

      if selected_repos.empty?
        redirect_to repository_onboarding_project_path(@project),
          alert: "Please select at least one repository."
        return
      end

      errors = []
      connected_repos = []

      selected_repos.each do |repo_params|
        repo_full_name = repo_params["github_repo"]
        installation_id = repo_params["installation_id"]

        next if repo_full_name.blank?

        # Find the installation
        installation = GithubAppInstallation.find_by(github_installation_id: installation_id)
        unless installation
          errors << "GitHub App installation not found for #{repo_full_name}."
          next
        end

        # Check if repo is already connected to another project
        existing_repo = ProjectRepository.find_by(github_repo: repo_full_name)
        if existing_repo && existing_repo.project_id != @project.id
          errors << "#{repo_full_name} is already connected to another project."
          next
        end

        # Create ProjectRepository record (new system)
        @project.project_repositories.find_or_create_by!(github_repo: repo_full_name) do |pr|
          pr.github_installation_id = installation.github_installation_id
          pr.is_primary = @project.project_repositories.empty?
        end

        connected_repos << repo_full_name
      end

      if connected_repos.empty? && errors.any?
        redirect_to repository_onboarding_project_path(@project), alert: errors.first
        return
      end

      # Update legacy fields for backwards compatibility (use primary repo)
      primary_repo = @project.primary_repository
      if primary_repo
        installation = GithubAppInstallation.find_by(github_installation_id: primary_repo.github_installation_id)
        @project.assign_attributes(
          github_repo: primary_repo.github_repo,
          github_app_installation: installation
        )
        @project.save!
      end

      @project.advance_onboarding!("setup")
      redirect_to setup_onboarding_project_path(@project)
    end

    # Step 2: Setup — project name, subdomain, and branch per repo
    def setup
      @project_repositories = @project.project_repositories.order(:created_at)
      @branches_by_repo = {}

      @project_repositories.each do |pr|
        result = GithubBranchesService.new(
          github_repo: pr.github_repo,
          installation_id: pr.github_installation_id
        ).call

        if result.success?
          @branches_by_repo[pr.id] = {
            branches: result.branches,
            default_branch: result.default_branch
          }
        else
          @branches_by_repo[pr.id] = {
            branches: [],
            default_branch: nil
          }
        end
      end
    end

    def save_setup
      # Update project name and subdomain
      name = params.dig(:project, :name)
      subdomain = params.dig(:project, :subdomain)

      @project.assign_attributes(name: name, subdomain: subdomain)
      @project.slug = subdomain.presence || name.to_s.parameterize

      # Validate name and subdomain
      @project.validate
      errors_to_check = @project.errors.select { |e| e.attribute.in?([ :name, :subdomain, :slug ]) }

      if errors_to_check.any?
        @project.errors.clear
        errors_to_check.each { |e| @project.errors.add(e.attribute, e.message) }
        @project_repositories = @project.project_repositories.order(:created_at)
        @branches_by_repo = {}
        @project_repositories.each do |pr|
          result = GithubBranchesService.new(
            github_repo: pr.github_repo,
            installation_id: pr.github_installation_id
          ).call
          @branches_by_repo[pr.id] = if result.success?
            { branches: result.branches, default_branch: result.default_branch }
          else
            { branches: [], default_branch: nil }
          end
        end
        render :setup, status: :unprocessable_entity
        return
      end

      @project.save(validate: false)

      # Save branch selections per repo
      repo_branches = params[:repo_branches] || {}
      @project.project_repositories.each do |pr|
        branch = repo_branches[pr.id.to_s]
        pr.update!(branch: branch.presence)
      end

      @project.advance_onboarding!("analyze")
      redirect_to analyze_onboarding_project_path(@project)
    end

    # Step 3: Analyze Codebase
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

    # Step 4: Review Sections
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

    # Step 5: Generating Recommendations (loading state)
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

    def ensure_onboarding_active
      unless @project.in_onboarding?
        redirect_to project_path(@project)
      end
    end

    def ensure_correct_step
      return if request.post? || request.patch? # Allow POST/PATCH actions for current step

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
        "setup" => "setup",
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

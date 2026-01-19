class SectionsController < ApplicationController
  before_action :set_project
  before_action :set_section, only: [ :show, :edit, :update, :destroy, :move, :generate_recommendations, :accept, :reject ]

  def index
    @sections = @project.sections.ordered.includes(:articles, :recommendations)
  end

  def show
    @articles = @section.articles.order(created_at: :desc)
    @pending_recommendations = @section.recommendations.pending
  end

  def new
    @section = @project.sections.build
  end

  def create
    @section = @project.sections.build(section_params)
    @section.section_type = :custom
    @section.position = @project.sections.maximum(:position).to_i + 1

    if @section.save
      respond_to do |format|
        format.turbo_stream { redirect_to project_sections_path(@project), notice: "Section created." }
        format.html { redirect_to project_sections_path(@project), notice: "Section created." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @section.update(section_params)
      respond_to do |format|
        format.turbo_stream { redirect_to project_sections_path(@project), notice: "Section updated." }
        format.html { redirect_to project_sections_path(@project), notice: "Section updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @section.articles.update_all(section_id: nil)
    @section.recommendations.update_all(section_id: nil)
    @section.destroy

    respond_to do |format|
      format.turbo_stream { redirect_to project_sections_path(@project), notice: "Section deleted." }
      format.html { redirect_to project_sections_path(@project), notice: "Section deleted." }
    end
  end

  def move
    new_position = params[:position].to_i
    @section.update!(position: new_position)

    # Reorder other sections
    @project.sections.where.not(id: @section.id).order(:position).each_with_index do |section, index|
      adjusted_position = index >= new_position ? index + 1 : index
      section.update_column(:position, adjusted_position)
    end

    head :ok
  end

  def generate_recommendations
    unless @project.analysis_status == "completed"
      redirect_to project_section_path(@project, @section), alert: "Please run codebase analysis first."
      return
    end

    GenerateSectionRecommendationsJob.perform_later(
      project_id: @project.id,
      section_id: @section.id
    )

    redirect_to project_section_path(@project, @section),
      notice: "Generating recommendations for #{@section.name}. This may take a few minutes."
  end

  def suggest_sections
    unless @project.analysis_status == "completed"
      redirect_to project_sections_path(@project), alert: "Please run codebase analysis first."
      return
    end

    SuggestSectionsJob.perform_later(project_id: @project.id)

    redirect_to project_sections_path(@project),
      notice: "Analyzing codebase to suggest additional sections. This may take a few minutes."
  end

  def accept
    @section.update!(status: :accepted)

    # Note: Recommendations are NOT generated here during onboarding.
    # They are generated in bulk via GenerateAllRecommendationsJob when
    # the user clicks "Complete" on the sections step. This prevents
    # duplicate recommendations across sections.

    # Check if all sections reviewed → can advance to articles step
    check_sections_complete_for_onboarding

    respond_to do |format|
      format.turbo_stream { render_section_update_streams }
      format.html { redirect_back fallback_location: project_path(@project), notice: "Section accepted." }
    end
  end

  def reject
    @section.update!(status: :rejected)

    # Check if all sections reviewed → can advance to articles step
    check_sections_complete_for_onboarding

    respond_to do |format|
      format.turbo_stream { render_section_update_streams }
      format.html { redirect_back fallback_location: project_path(@project), notice: "Section dismissed." }
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_section
    @section = @project.sections.find(params[:id])
  end

  def section_params
    params.require(:section).permit(:name, :description, :visible)
  end

  def check_sections_complete_for_onboarding
    # No-op: User must click "Complete" to finish onboarding
    # This method is kept for potential future use (e.g., enabling the complete button)
  end

  def render_section_update_streams
    can_continue = @project.sections.pending.empty? && !@project.sections_being_generated?

    render turbo_stream: [
      turbo_stream.remove(@section),
      turbo_stream.update(
        "onboarding-sections-navigation",
        partial: "onboarding/projects/sections_navigation",
        locals: { project: @project, can_continue: can_continue }
      )
    ]
  end
end

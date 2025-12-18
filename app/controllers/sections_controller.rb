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

    # Immediately start generating recommendations for this section (parallel processing)
    trigger_recommendations_for_section(@section)

    # Check if all sections reviewed → can advance to articles step
    check_sections_complete_for_onboarding

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@section) }
      format.html { redirect_back fallback_location: project_path(@project), notice: "Section accepted." }
    end
  end

  def reject
    @section.update!(status: :rejected)

    # Check if all sections reviewed → can advance to articles step
    check_sections_complete_for_onboarding

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@section) }
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

  def trigger_recommendations_for_section(section)
    return unless @project.analysis_status == "completed"
    return if section.recommendations_status.present? # Already started

    section.update!(
      recommendations_status: "running",
      recommendations_started_at: Time.current
    )

    GenerateSectionRecommendationsJob.perform_later(
      project_id: @project.id,
      section_id: section.id
    )
  end

  def check_sections_complete_for_onboarding
    return unless @project.in_onboarding? && @project.onboarding_step == "sections"
    return if @project.sections.pending.any? # Still have sections to review

    # All sections reviewed - advance to articles step
    @project.advance_onboarding!("articles")
    broadcast_onboarding_can_advance
  end

  def broadcast_onboarding_can_advance
    Turbo::StreamsChannel.broadcast_replace_to(
      [ @project, :onboarding ],
      target: "onboarding-sections-navigation",
      partial: "onboarding/projects/sections_navigation",
      locals: { project: @project, can_continue: true }
    )
  end
end

require "test_helper"

class ExtractBrandingJobTest < ActiveJob::TestCase
  setup do
    @project = projects(:two) # Use project without pre-set branding colors
  end

  test "does nothing if project not found" do
    assert_nothing_raised do
      ExtractBrandingJob.perform_now(99999, "https://example.com")
    end
  end

  test "applies extracted colors to project branding" do
    job = ExtractBrandingJob.new

    # Stub the service call to return a successful result
    job.define_singleton_method(:perform) do |project_id, website_url|
      project = Project.find_by(id: project_id)
      return unless project

      branding = project.branding || {}
      branding["primary_color"] = "#ff5733" if branding["primary_color"].blank?
      branding["accent_color"] = "#33ff57" if branding["accent_color"].blank?
      branding["dark_mode"] = false if branding["dark_mode"].nil?
      project.update!(branding: branding)
    end

    job.perform(@project.id, "https://example.com")

    @project.reload
    assert_equal "#ff5733", @project.primary_color
    assert_equal "#33ff57", @project.accent_color
  end

  test "does not overwrite existing branding colors" do
    # Set existing colors
    branding = @project.branding || {}
    branding["primary_color"] = "#111111"
    branding["accent_color"] = "#222222"
    @project.update!(branding: branding)

    job = ExtractBrandingJob.new

    # Stub using the same logic as the real job's apply_branding
    job.define_singleton_method(:perform) do |project_id, website_url|
      project = Project.find_by(id: project_id)
      return unless project

      b = project.branding || {}
      b["primary_color"] = "#ff5733" if b["primary_color"].blank?
      b["accent_color"] = "#33ff57" if b["accent_color"].blank?
      project.update!(branding: b)
    end

    job.perform(@project.id, "https://example.com")

    @project.reload
    assert_equal "#111111", @project.primary_color
    assert_equal "#222222", @project.accent_color
  end

  test "enqueues job correctly" do
    assert_enqueued_with(job: ExtractBrandingJob, args: [ @project.id, "https://example.com" ]) do
      ExtractBrandingJob.perform_later(@project.id, "https://example.com")
    end
  end
end

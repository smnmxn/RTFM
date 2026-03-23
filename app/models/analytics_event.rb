class AnalyticsEvent < ApplicationRecord
  belongs_to :visitor, primary_key: :visitor_id, foreign_key: :visitor_id, optional: true
  belongs_to :project, optional: true

  EVENT_TYPES = %w[page_view video_play video_progress waitlist_submit cta_click signup].freeze

  validates :visitor_id, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :page_path, presence: true

  store :event_data, coder: JSON

  scope :page_views, -> { where(event_type: "page_view") }
  scope :engagement, -> { where.not(event_type: "page_view") }
  scope :since, ->(date) { where("created_at >= ?", date) }
  scope :between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :for_project, ->(pid) { where(project_id: pid) }
  scope :help_centre, -> { where.not(project_id: nil) }
end

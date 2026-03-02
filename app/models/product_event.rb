class ProductEvent < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  validates :event_name, presence: true
  validates :category, presence: true

  before_validation :set_category

  scope :since, ->(date) { where("created_at >= ?", date) }
  scope :between, ->(start_date, end_date) { where(created_at: start_date..end_date) }
  scope :for_event, ->(name) { where(event_name: name) }
  scope :for_category, ->(cat) { where(category: cat) }
  scope :for_project, ->(project_id) { where(project_id: project_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  private

  def set_category
    self.category = event_name.to_s.split(".").first if event_name.present? && category.blank?
  end
end

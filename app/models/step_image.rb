class StepImage < ApplicationRecord
  belongs_to :article
  has_one_attached :image

  validates :step_index, presence: true
  validates :step_index, uniqueness: { scope: :article_id }
  validates :image, presence: true

  def thumbnail
    image.variant(resize_to_limit: [ 200, 200 ])
  end

  def display
    image.variant(resize_to_limit: [ 800, 600 ])
  end
end

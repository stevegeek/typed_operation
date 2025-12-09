class Order < ApplicationRecord
  STATUSES = %w[pending confirmed cancelled].freeze

  belongs_to :user
  belongs_to :product

  validates :status, inclusion: {in: STATUSES}
  validates :quantity, numericality: {greater_than: 0}
  validates :total, numericality: {greater_than_or_equal_to: 0}

  scope :recent, -> { where("created_at >= ?", 30.days.ago) }
  scope :by_status, ->(status) { where(status: status) }

  def confirm! = update!(status: "confirmed")
  def cancel! = update!(status: "cancelled")
end

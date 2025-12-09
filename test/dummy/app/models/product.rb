class Product < ApplicationRecord
  PEN_TYPES = %w[ballpoint fountain gel rollerball marker].freeze

  has_many :orders, dependent: :restrict_with_error

  validates :name, presence: true
  validates :price, presence: true, numericality: {greater_than: 0}
  validates :pen_type, inclusion: {in: PEN_TYPES}
  validates :stock_quantity, numericality: {greater_than_or_equal_to: 0}

  scope :in_stock, -> { where("stock_quantity > 0") }
  scope :by_type, ->(type) { where(pen_type: type) }

  def in_stock? = stock_quantity > 0

  def reserve_stock!(quantity)
    raise "Insufficient stock" if stock_quantity < quantity
    decrement!(:stock_quantity, quantity)
  end
end

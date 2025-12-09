class User < ApplicationRecord
  ROLES = %w[customer admin].freeze

  has_many :orders, dependent: :destroy

  validates :email, presence: true
  validates :name, presence: true
  validates :role, inclusion: {in: ROLES}

  def admin? = role == "admin"
end

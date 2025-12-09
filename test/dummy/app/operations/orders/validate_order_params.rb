# frozen_string_literal: true

module Orders
  class ValidateOrderParams < ApplicationOperation
    param :user_id, Integer
    param :product_id, Integer
    param :quantity, Integer
    param :skip_stock_check, _Boolean, default: false

    def perform
      user = User.find_by(id: user_id)
      return Failure(error: :user_not_found) unless user

      product = Product.find_by(id: product_id)
      return Failure(error: :product_not_found) unless product

      return Failure(error: :invalid_quantity) unless quantity > 0

      Success(user:, product:, quantity:, skip_stock_check:)
    end
  end
end

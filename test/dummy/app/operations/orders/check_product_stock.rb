# frozen_string_literal: true

module Orders
  class CheckProductStock < ApplicationOperation
    param :product, Product
    param :quantity, Integer
    param :user, User
    param :skip_stock_check, _Boolean, default: false

    def perform
      if product.stock_quantity >= quantity
        Success(user:, product:, quantity:, skip_stock_check:)
      else
        Failure(error: :insufficient_stock, available: product.stock_quantity)
      end
    end
  end
end

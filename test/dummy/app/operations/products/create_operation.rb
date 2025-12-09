# frozen_string_literal: true

module Products
  # Simple standalone operation example.
  class CreateOperation < ApplicationOperation
    param :name, String
    param :price, Numeric
    param :pen_type, String
    param :stock_quantity, Integer, default: 0

    def perform
      product = Product.new(name:, price:, pen_type:, stock_quantity:)

      if product.save
        Success(product:)
      else
        Failure(errors: product.errors.full_messages)
      end
    end
  end
end

# frozen_string_literal: true

module Orders
  class CreateOrderRecord < ApplicationOperation
    param :user, User
    param :product, Product
    param :quantity, Integer
    param :total, Numeric, default: nil
    param :skip_stock_check, _Boolean, default: false

    def perform
      calculated_total = total || (product.price * quantity)

      order = Order.new(
        user:,
        product:,
        quantity:,
        total: calculated_total,
        status: "pending"
      )

      if order.save
        product.reserve_stock!(quantity)
        Success(user:, product:, quantity:, order:)
      else
        Failure(error: :order_creation_failed, messages: order.errors.full_messages)
      end
    end
  end
end

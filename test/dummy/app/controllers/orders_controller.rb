# frozen_string_literal: true

class OrdersController < ApplicationController
  Success = TypedOperation::Result::Success
  Failure = TypedOperation::Result::Failure

  def index
    @orders = Order.includes(:user, :product).recent
    render json: @orders
  end

  def create
    result = Orders::ValidateOrderParams
      .then(Orders::CheckProductStock)
      .then(Orders::CreateOrderRecord)
      .call(**order_params)

    case result
    in Success(order:)
      render json: order, status: :created
    in Failure(error: :user_not_found)
      render json: {error: "User not found"}, status: :not_found
    in Failure(error: :product_not_found)
      render json: {error: "Product not found"}, status: :not_found
    in Failure(error: :insufficient_stock, available:)
      render json: {error: "Insufficient stock", available:}, status: :unprocessable_entity
    in Failure(error:)
      render json: {error:}, status: :unprocessable_entity
    end
  end

  def create_via_pipeline
    result = Orders::ProcessOrderPipeline.call(**order_params)

    case result
    in Success(order:)
      render json: order, status: :created
    in Failure(error:)
      render json: {error:}, status: :unprocessable_entity
    end
  end

  private

  def order_params
    params.permit(:user_id, :product_id, :quantity, :skip_stock_check).to_h.symbolize_keys
  end
end

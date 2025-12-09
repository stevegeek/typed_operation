# frozen_string_literal: true

class ProductsController < ApplicationController
  Success = TypedOperation::Result::Success
  Failure = TypedOperation::Result::Failure

  def index
    @products = Product.all
    render json: @products
  end

  def create
    result = Products::CreateOperation.call(**product_params)

    case result
    in Success(product:)
      render json: product, status: :created
    in Failure(errors:)
      render json: {errors:}, status: :unprocessable_entity
    end
  end

  private

  def product_params
    params.permit(:name, :price, :pen_type, :stock_quantity).to_h.symbolize_keys
  end
end

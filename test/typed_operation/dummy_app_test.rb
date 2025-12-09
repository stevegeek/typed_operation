# frozen_string_literal: true

require "test_helper"

return if ENV["NO_RAILS"]

class DummyAppTest < ActiveSupport::TestCase
  Success = TypedOperation::Result::Success
  Failure = TypedOperation::Result::Failure

  # Inline composition chain (same as in OrdersController)
  PlaceOrder = Orders::ValidateOrderParams
    .then(Orders::CheckProductStock)
    .then(Orders::CreateOrderRecord)

  setup do
    Order.delete_all
    Product.delete_all
    User.delete_all
  end

  test "Products::CreateOperation creates a product" do
    result = Products::CreateOperation.call(
      name: "Test Ballpoint",
      price: 9.99,
      pen_type: "ballpoint",
      stock_quantity: 50
    )

    assert_kind_of Success, result
    case result
    in Success(product:)
      assert_equal "Test Ballpoint", product.name
      assert_equal 50, product.stock_quantity
    end
  end

  test "Products::CreateOperation returns failure on invalid data" do
    result = Products::CreateOperation.call(
      name: "",
      price: 9.99,
      pen_type: "ballpoint",
      stock_quantity: 50
    )

    assert_kind_of Failure, result
    case result
    in Failure(errors:)
      assert_includes errors, "Name can't be blank"
    end
  end

  test "PlaceOrder composition chain creates an order" do
    user = User.create!(name: "Test User", email: "test@example.com", role: "customer")
    product = Product.create!(name: "Fountain Pen", price: 29.99, pen_type: "fountain", stock_quantity: 10)

    result = PlaceOrder.call(user_id: user.id, product_id: product.id, quantity: 2)

    assert_kind_of Success, result
    case result
    in Success(order:, user: result_user, product: result_product)
      assert_equal user, result_user
      assert_equal product.id, result_product.id
      assert_equal 2, order.quantity
      assert_in_delta 59.98, order.total, 0.01
    end

    product.reload
    assert_equal 8, product.stock_quantity
  end

  test "PlaceOrder returns failure for user not found" do
    product = Product.create!(name: "Pen", price: 9.99, pen_type: "ballpoint", stock_quantity: 10)

    result = PlaceOrder.call(user_id: 99999, product_id: product.id, quantity: 1)

    assert_kind_of Failure, result
    case result
    in Failure(error: :user_not_found)
      assert true
    else
      flunk "Expected Failure(error: :user_not_found)"
    end
  end

  test "PlaceOrder returns failure for product not found" do
    user = User.create!(name: "Test", email: "test@example.com", role: "customer")

    result = PlaceOrder.call(user_id: user.id, product_id: 99999, quantity: 1)

    assert_kind_of Failure, result
    case result
    in Failure(error: :product_not_found)
      assert true
    else
      flunk "Expected Failure(error: :product_not_found)"
    end
  end

  test "PlaceOrder returns failure for insufficient stock" do
    user = User.create!(name: "Test", email: "test@example.com", role: "customer")
    product = Product.create!(name: "Pen", price: 9.99, pen_type: "ballpoint", stock_quantity: 5)

    result = PlaceOrder.call(user_id: user.id, product_id: product.id, quantity: 100)

    assert_kind_of Failure, result
    case result
    in Failure(error: :insufficient_stock, available:)
      assert_equal 5, available
    else
      flunk "Expected Failure(error: :insufficient_stock)"
    end
  end

  test "ProcessOrderPipeline creates an order" do
    user = User.create!(name: "Test User", email: "test@example.com", role: "customer")
    product = Product.create!(name: "Gel Pen", price: 4.99, pen_type: "gel", stock_quantity: 100)

    result = Orders::ProcessOrderPipeline.call(user_id: user.id, product_id: product.id, quantity: 5)

    assert_kind_of Success, result
    case result
    in Success(order:, total:)
      assert_equal 5, order.quantity
      assert_in_delta 24.95, total, 0.01
      assert_in_delta 24.95, order.total, 0.01
    end

    product.reload
    assert_equal 95, product.stock_quantity
  end

  test "ProcessOrderPipeline skips stock check when skip_stock_check is true" do
    user = User.create!(name: "Test", email: "test@example.com", role: "customer")
    product = Product.create!(name: "Pen", price: 29.99, pen_type: "fountain", stock_quantity: 5)

    # skip_stock_check skips validation but reserve_stock! still enforces it
    # so we test with valid quantity but verify the check step was skipped
    result = Orders::ProcessOrderPipeline.call(
      user_id: user.id,
      product_id: product.id,
      quantity: 3,
      skip_stock_check: true
    )

    assert_kind_of Success, result
    case result
    in Success(order:, skip_stock_check:)
      assert_equal 3, order.quantity
      assert skip_stock_check
    end
  end

  test "pattern matching on Success extracts values" do
    user = User.create!(name: "Test", email: "test@example.com", role: "customer")
    product = Product.create!(name: "Pen", price: 10.00, pen_type: "ballpoint", stock_quantity: 10)

    result = PlaceOrder.call(user_id: user.id, product_id: product.id, quantity: 1)

    matched = case result
    in Success(order:, user:, product:)
      {order_id: order.id, user_email: user.email, product_name: product.name}
    in Failure
      nil
    end

    assert_equal user.email, matched[:user_email]
    assert_equal product.name, matched[:product_name]
  end

  test "pattern matching on Failure extracts error details" do
    user = User.create!(name: "Test", email: "test@example.com", role: "customer")
    product = Product.create!(name: "Pen", price: 10.00, pen_type: "ballpoint", stock_quantity: 2)

    result = PlaceOrder.call(user_id: user.id, product_id: product.id, quantity: 100)

    matched = case result
    in Success
      nil
    in Failure(error: :insufficient_stock, available:)
      {error: :insufficient_stock, available: available}
    in Failure(error:)
      {error: error}
    end

    assert_equal :insufficient_stock, matched[:error]
    assert_equal 2, matched[:available]
  end
end

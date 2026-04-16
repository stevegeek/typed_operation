# frozen_string_literal: true

require "test_helper"

# Integration test demonstrating natural operation chaining with typed parameters.
# Each operation declares exactly the parameters it needs and returns a hash
# that can be splatted into the next operation.
class IntegrationExampleTest < Minitest::Test
  include Dry::Monads[:result]
  include Literal::Types

  def setup
    TypedOperation.configure { |c| c.result_adapter = :dry_monads }
  end

  def teardown
    TypedOperation.reset_configuration!
  end

  # ============================================================================
  # TYPED DATA STRUCTURES - Small, focused value objects
  # ============================================================================

  Item = Data.define(:sku, :quantity, :price)
  PaymentMethod = Data.define(:card_last4, :card_type) do
    def initialize(card_last4:, card_type: "visa")
      super
    end
  end

  # ============================================================================
  # ORDER VALIDATION OPERATIONS
  # ============================================================================

  class ValidateOrder < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :items, _Array(Item)
    param :promo_code, optional(String)

    def perform
      return Failure([:validation_error, "No items provided"]) if items.empty?
      return Failure([:validation_error, "Invalid customer"]) if customer_id <= 0

      total = items.sum { |item| item.price * item.quantity }

      Success(
        customer_id: customer_id,
        items: items,
        promo_code: promo_code,
        subtotal: total
      )
    end
  end

  class CheckInventory < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :items, _Array(Item)
    param :promo_code, optional(String)
    param :subtotal, Numeric

    def perform
      out_of_stock = items.select { |item| item.quantity > 100 }
      return Failure([:out_of_stock, out_of_stock.map(&:sku)]) if out_of_stock.any?

      Success(
        customer_id: customer_id,
        items: items,
        promo_code: promo_code,
        subtotal: subtotal,
        inventory_checked: true
      )
    end
  end

  # ============================================================================
  # PRICING OPERATIONS
  # ============================================================================

  class CalculateShipping < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :items, _Array(Item)
    param :promo_code, optional(String)
    param :subtotal, Numeric
    param :inventory_checked, _Boolean

    def perform
      item_count = items.sum(&:quantity)
      shipping = (item_count * 2.50).round(2)

      Success(
        customer_id: customer_id,
        items: items,
        promo_code: promo_code,
        subtotal: subtotal,
        shipping_cost: shipping
      )
    end
  end

  class ApplyDiscount < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :items, _Array(Item)
    param :promo_code, optional(String)
    param :subtotal, Numeric
    param :shipping_cost, Numeric

    def perform
      discount = (promo_code == "SAVE10") ? (subtotal * 0.10).round(2) : 0.0
      total = subtotal + shipping_cost - discount

      Success(
        customer_id: customer_id,
        items: items,
        subtotal: subtotal,
        shipping_cost: shipping_cost,
        discount: discount,
        total: total
      )
    end
  end

  # ============================================================================
  # PAYMENT OPERATIONS
  # ============================================================================

  class ProcessPayment < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :total, Numeric
    param :payment_method, PaymentMethod

    def perform
      return Failure([:payment_failed, "Card declined"]) if payment_method.card_last4 == "0000"

      Success(
        customer_id: customer_id,
        total: total,
        payment_id: "pay_#{rand(100000)}",
        payment_gateway: "primary"
      )
    end
  end

  class ProcessPaymentViaBackup < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :total, Numeric
    param :payment_method, PaymentMethod

    def perform
      Success(
        customer_id: customer_id,
        total: total,
        payment_id: "pay_backup_#{rand(100000)}",
        payment_gateway: "backup"
      )
    end
  end

  # ============================================================================
  # FULFILLMENT OPERATIONS
  # ============================================================================

  class ReserveInventory < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :items, _Array(Item)
    param :payment_id, String

    def perform
      Success(
        customer_id: customer_id,
        items: items,
        payment_id: payment_id,
        reservation_id: "rsv_#{rand(100000)}"
      )
    end
  end

  class CreateShipment < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :items, _Array(Item)
    param :payment_id, String
    param :reservation_id, String

    def perform
      Success(
        customer_id: customer_id,
        items: items,
        reservation_id: reservation_id,
        tracking_number: "TRK#{rand(1000000000)}"
      )
    end
  end

  class SendConfirmation < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer
    param :tracking_number, String

    def perform
      Success(
        customer_id: customer_id,
        tracking_number: tracking_number,
        confirmation_sent: true
      )
    end
  end

  # ============================================================================
  # BASIC CHAINING - Smart .then auto-splats to kwargs operations
  # ============================================================================

  def test_basic_order_validation_chain
    # ValidateOrder returns hash, CheckInventory takes kwargs → auto-splat
    chain = ValidateOrder.then(CheckInventory)

    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 29.99)]
    result = chain.call(customer_id: 123, items: items)

    assert result.success?
    assert result.value![:inventory_checked]
    assert_equal 123, result.value![:customer_id]
    assert_equal 59.98, result.value![:subtotal]
  end

  def test_pricing_chain
    chain = ValidateOrder
      .then(CheckInventory)
      .then(CalculateShipping)
      .then(ApplyDiscount)

    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 50.00)]
    result = chain.call(customer_id: 123, items: items, promo_code: "SAVE10")

    assert result.success?
    value = result.value!

    assert_equal 100.00, value[:subtotal]
    assert_equal 5.00, value[:shipping_cost]
    assert_equal 10.00, value[:discount]
    assert_equal 95.00, value[:total]
  end

  def test_chain_stops_on_validation_failure
    chain = ValidateOrder.then(CheckInventory)

    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 29.99)]
    result = chain.call(customer_id: -1, items: items)

    assert result.failure?
    code, message = result.failure
    assert_equal :validation_error, code
    assert_equal "Invalid customer", message
  end

  def test_chain_stops_on_inventory_failure
    chain = ValidateOrder.then(CheckInventory)

    items = [Item.new(sku: "WIDGET-1", quantity: 500, price: 29.99)]
    result = chain.call(customer_id: 123, items: items)

    assert result.failure?
    code, skus = result.failure
    assert_equal :out_of_stock, code
    assert_includes skus, "WIDGET-1"
  end

  # ============================================================================
  # TRANSFORM - Bridging between operations with different signatures
  # ============================================================================

  def test_transform_to_adapt_for_payment
    # Pricing chain returns: {customer_id, items, subtotal, shipping_cost, discount, total}
    # ProcessPayment expects: {customer_id, total, payment_method}
    # Use transform to adapt

    pricing_chain = ValidateOrder
      .then(CheckInventory)
      .then(CalculateShipping)
      .then(ApplyDiscount)

    payment_chain = pricing_chain.transform do |result|
      {
        customer_id: result[:customer_id],
        total: result[:total],
        payment_method: PaymentMethod.new(card_last4: "1234")
      }
    end.then(ProcessPayment)

    items = [Item.new(sku: "WIDGET-1", quantity: 1, price: 100.00)]
    result = payment_chain.call(customer_id: 123, items: items)

    assert result.success?
    assert result.value![:payment_id]
    assert_equal "primary", result.value![:payment_gateway]
  end

  # ============================================================================
  # OR_ELSE - Payment fallback
  # ============================================================================

  def test_payment_with_fallback
    payment_with_fallback = ProcessPayment.or_else(ProcessPaymentViaBackup)

    result = payment_with_fallback.call(
      customer_id: 123,
      total: 99.99,
      payment_method: PaymentMethod.new(card_last4: "0000") # Will fail primary
    )

    assert result.success?
    assert_equal "backup", result.value![:payment_gateway]
    assert result.value![:payment_id].start_with?("pay_backup_")
  end

  def test_payment_primary_success
    payment_with_fallback = ProcessPayment.or_else(ProcessPaymentViaBackup)

    result = payment_with_fallback.call(
      customer_id: 123,
      total: 99.99,
      payment_method: PaymentMethod.new(card_last4: "1234")
    )

    assert result.success?
    assert_equal "primary", result.value![:payment_gateway]
  end

  # ============================================================================
  # FULFILLMENT CHAIN
  # ============================================================================

  def test_fulfillment_chain
    # Note: When chaining, output must match next operation's expected params.
    # CreateShipment outputs {customer_id, items, reservation_id, tracking_number}
    # SendConfirmation expects only {customer_id, tracking_number}
    # Use .transform to adapt the signature
    chain = ReserveInventory
      .then(CreateShipment)
      .transform { |r| {customer_id: r[:customer_id], tracking_number: r[:tracking_number]} }
      .then(SendConfirmation)

    items = [Item.new(sku: "WIDGET-1", quantity: 1, price: 29.99)]
    result = chain.call(
      customer_id: 123,
      items: items,
      payment_id: "pay_123"
    )

    assert result.success?
    assert result.value![:tracking_number]
    assert result.value![:confirmation_sent]
  end

  # ============================================================================
  # AND_THEN - Custom logic between steps
  # ============================================================================

  def test_then_passes_for_conditional_logic
    # then_passes allows custom logic between operations
    # Here we conditionally skip inventory check for small orders
    chain = ValidateOrder.then_passes do |result|
      if result[:subtotal] < 10
        # Small orders bypass inventory check
        Success(result.merge(inventory_checked: false, skipped_check: true))
      else
        CheckInventory.call(**result)
      end
    end

    # Large order goes through inventory check
    items = [Item.new(sku: "WIDGET-1", quantity: 5, price: 50.00)]
    result = chain.call(customer_id: 123, items: items)
    assert result.success?
    assert result.value![:inventory_checked]

    # Small order skips inventory check
    small_items = [Item.new(sku: "SAMPLE", quantity: 1, price: 1.00)]
    small_result = chain.call(customer_id: 123, items: small_items)
    assert small_result.success?
    assert small_result.value![:skipped_check]
  end

  # ============================================================================
  # COMPLETE ORDER FLOW - Combining all patterns
  # ============================================================================

  def test_complete_order_flow
    # With context accumulation, chaining is simple:
    # - Each step's output merges into context
    # - .then extracts only the params each operation needs
    # - Use .with or extra kwargs for params not in context

    payment_with_fallback = ProcessPayment.or_else(ProcessPaymentViaBackup)

    complete_flow = ValidateOrder
      .then(CheckInventory)
      .then(CalculateShipping)
      .then(ApplyDiscount)
      .then(payment_with_fallback, payment_method: PaymentMethod.new(card_last4: "1234"))
      .then(ReserveInventory)
      .then(CreateShipment)
      .then(SendConfirmation)

    items = [
      Item.new(sku: "WIDGET-1", quantity: 2, price: 29.99),
      Item.new(sku: "GADGET-2", quantity: 1, price: 49.99)
    ]

    result = complete_flow.call(
      customer_id: 123,
      items: items,
      promo_code: "SAVE10"
    )

    assert result.success?
    value = result.value!

    assert_equal 123, value[:customer_id]
    assert value[:discount] > 0
    assert value[:payment_id]
    assert value[:tracking_number]
    assert value[:confirmation_sent]
  end

  # ============================================================================
  # EXPLICIT METHODS - then_spreads and then_passes
  # ============================================================================

  def test_then_spreads_explicit
    # Same as .then for kwargs operations, but explicit
    chain = ValidateOrder.then_spreads(CheckInventory)

    items = [Item.new(sku: "WIDGET-1", quantity: 1, price: 29.99)]
    result = chain.call(customer_id: 123, items: items)

    assert result.success?
    assert result.value![:inventory_checked]
  end

  # Operation that takes a single positional value
  class LogOrder < TypedOperation::Base
    include Dry::Monads[:result]

    positional_param :data, Hash

    def perform
      Success(data.merge(logged: true))
    end
  end

  def test_then_passes_value_explicit
    # Force passing as single value (for operations with positional_param)
    chain = ValidateOrder.then_passes(LogOrder)

    items = [Item.new(sku: "WIDGET-1", quantity: 1, price: 29.99)]
    result = chain.call(customer_id: 123, items: items)

    assert result.success?
    assert result.value![:logged]
    assert_equal 123, result.value![:customer_id]
  end

  # ============================================================================
  # TYPE SAFETY - Literal type checking in action
  # ============================================================================

  def test_type_checking_on_items
    assert_raises Literal::TypeError do
      ValidateOrder.call(
        customer_id: 123,
        items: ["not", "items"]  # Should be Array of Item
      )
    end
  end

  def test_type_checking_on_customer_id
    assert_raises Literal::TypeError do
      ValidateOrder.call(
        customer_id: "not an integer",
        items: [Item.new(sku: "X", quantity: 1, price: 10.0)]
      )
    end
  end

  def test_type_checking_on_payment_method
    assert_raises Literal::TypeError do
      ProcessPayment.call(
        customer_id: 123,
        total: 99.99,
        payment_method: {card_last4: "1234"}  # Should be PaymentMethod, not Hash
      )
    end
  end

  # ============================================================================
  # PATTERN MATCHING - Chain results work with Ruby pattern matching
  # ============================================================================

  def test_pattern_matching_on_success
    chain = ValidateOrder.then(CheckInventory)
    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 29.99)]
    result = chain.call(customer_id: 123, items: items)

    matched = case result
    in Dry::Monads::Success(customer_id:, subtotal:, inventory_checked:, **rest)
      {customer_id: customer_id, subtotal: subtotal, inventory_checked: inventory_checked}
    in Dry::Monads::Failure(code, message)
      {error: code, message: message}
    end

    assert_equal 123, matched[:customer_id]
    assert_equal 59.98, matched[:subtotal]
    assert matched[:inventory_checked]
  end

  def test_pattern_matching_on_failure
    chain = ValidateOrder.then(CheckInventory)
    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 29.99)]
    result = chain.call(customer_id: -1, items: items)  # Invalid customer

    matched = case result
    in Dry::Monads::Success(value)
      {success: value}
    in Dry::Monads::Failure[:validation_error, message]
      {error: :validation_error, message: message}
    in Dry::Monads::Failure[:out_of_stock, skus]
      {error: :out_of_stock, skus: skus}
    end

    assert_equal :validation_error, matched[:error]
    assert_equal "Invalid customer", matched[:message]
  end

  def test_pattern_matching_with_inventory_failure
    chain = ValidateOrder.then(CheckInventory)
    items = [Item.new(sku: "BULK-ITEM", quantity: 500, price: 5.00)]
    result = chain.call(customer_id: 123, items: items)

    matched = case result
    in Dry::Monads::Success
      :success
    in Dry::Monads::Failure[:out_of_stock, skus]
      {error: :out_of_stock, skus: skus}
    in Dry::Monads::Failure
      :other_failure
    end

    assert_equal :out_of_stock, matched[:error]
    assert_includes matched[:skus], "BULK-ITEM"
  end

  def test_case_statement_with_success_and_failure
    chain = ValidateOrder
      .then(CheckInventory)
      .then(CalculateShipping)
      .then(ApplyDiscount)

    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 50.00)]

    # Success case
    success_result = chain.call(customer_id: 123, items: items, promo_code: "SAVE10")
    success_response = case success_result
    when Dry::Monads::Success
      {status: :ok, total: success_result.value![:total]}
    when Dry::Monads::Failure
      {status: :error, reason: success_result.failure}
    end

    assert_equal :ok, success_response[:status]
    assert_equal 95.00, success_response[:total]

    # Failure case
    failure_result = chain.call(customer_id: -1, items: items)
    failure_response = case failure_result
    when Dry::Monads::Success
      {status: :ok, total: failure_result.value![:total]}
    when Dry::Monads::Failure
      {status: :error, reason: failure_result.failure}
    end

    assert_equal :error, failure_response[:status]
    assert_equal [:validation_error, "Invalid customer"], failure_response[:reason]
  end

  # ============================================================================
  # CONTEXT ACCUMULATION - Data persists across chain steps
  # ============================================================================

  def test_context_accumulates_across_steps
    # Each step's output merges into context, so later steps can access earlier data
    chain = ValidateOrder
      .then(CheckInventory)
      .then(CalculateShipping)
      .then(ApplyDiscount)

    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 50.00)]
    result = chain.call(customer_id: 123, items: items, promo_code: "SAVE10")

    assert result.success?
    ctx = result.value!

    # All data from all steps is available in final context
    assert_equal 123, ctx[:customer_id]
    assert_equal items, ctx[:items]
    assert_equal 100.00, ctx[:subtotal]
    assert ctx[:inventory_checked]
    assert_equal 5.00, ctx[:shipping_cost]
    assert_equal 10.00, ctx[:discount]
    assert_equal 95.00, ctx[:total]
  end

  def test_extra_kwargs_in_then_are_merged
    # Extra kwargs passed to .then are merged when calling the operation
    payment = ProcessPayment.or_else(ProcessPaymentViaBackup)

    chain = ApplyDiscount
      .then(payment, payment_method: PaymentMethod.new(card_last4: "9999"))

    result = chain.call(
      customer_id: 123,
      items: [],
      subtotal: 100.00,
      shipping_cost: 5.00
    )

    assert result.success?
    assert result.value![:payment_id]
  end

  def test_with_and_extra_kwargs_are_equivalent
    # .then(op.with(key: val)) is equivalent to .then(op, key: val)
    payment = ProcessPayment

    chain_with_dot_with = ApplyDiscount
      .then(payment.with(payment_method: PaymentMethod.new(card_last4: "1111")))

    chain_with_extra_kwargs = ApplyDiscount
      .then(payment, payment_method: PaymentMethod.new(card_last4: "1111"))

    input = {customer_id: 123, items: [], subtotal: 100.00, shipping_cost: 5.00}

    result1 = chain_with_dot_with.call(**input)
    result2 = chain_with_extra_kwargs.call(**input)

    assert result1.success?
    assert result2.success?
    # Both should work and produce payment_id
    assert result1.value![:payment_id]
    assert result2.value![:payment_id]
  end

  def test_missing_required_param_raises_helpful_error
    # If a required param is missing from context and not provided via .with, raise
    chain = ValidateOrder.then(ProcessPayment)  # ProcessPayment needs payment_method!

    items = [Item.new(sku: "X", quantity: 1, price: 10.0)]

    error = assert_raises ArgumentError do
      chain.call(customer_id: 123, items: items)
    end

    assert_match(/Missing required parameters.*payment_method/i, error.message)
  end

  class OverrideCustomerId < TypedOperation::Base
    include Dry::Monads[:result]

    param :customer_id, Integer

    def perform
      Success(customer_id: customer_id, override_applied: true)
    end
  end

  def test_prefilled_params_override_context
    # Params from .with take precedence over context
    # This is useful for explicitly overriding values

    chain = ValidateOrder
      .then(OverrideCustomerId.with(customer_id: 999))

    items = [Item.new(sku: "X", quantity: 1, price: 10.0)]
    result = chain.call(customer_id: 123, items: items)

    assert result.success?
    # customer_id from .with (999) was used, then result (999) merged into context
    # Original 123 was overwritten by operation result
    assert_equal 999, result.value![:customer_id]
    assert result.value![:override_applied]
  end

  def test_transform_in_middle_of_chain
    # Transform can modify existing keys or add new computed values mid-chain
    # The transform receives context and its return replaces the context

    chain = ValidateOrder
      .then(CheckInventory)
      .transform do |ctx|
        # Add new computed key AND modify existing key
        ctx.merge(
          vip_customer: ctx[:customer_id] < 100,
          subtotal: ctx[:subtotal] * 1.1  # Apply 10% markup
        )
    end

    chain = chain.then(CalculateShipping)
      .transform { |ctx| ctx.merge(priority_shipping: ctx[:vip_customer] && ctx[:subtotal] > 50) }
      .then(ApplyDiscount)

    items = [Item.new(sku: "WIDGET-1", quantity: 2, price: 50.00)]

    # VIP customer (id < 100) - subtotal was 100, now 110 after markup
    vip_result = chain.call(customer_id: 42, items: items, promo_code: "SAVE10")
    assert vip_result.success?
    assert vip_result.value![:vip_customer]
    assert vip_result.value![:priority_shipping]
    # Verify subtotal was modified by transform (100 * 1.1 = 110)
    # Final total = 110 + 5 (shipping) - 11 (10% of 110) = 104
    assert_in_delta 104.00, vip_result.value![:total], 0.01

    # Non-VIP customer
    regular_result = chain.call(customer_id: 123, items: items, promo_code: "SAVE10")
    assert regular_result.success?
    refute regular_result.value![:vip_customer]
    refute regular_result.value![:priority_shipping]
  end
end

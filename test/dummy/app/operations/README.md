# TypedOperation Demo: Online Pen Shop

This directory contains TypedOperation examples for a fictional online pen shop, demonstrating the gem's key features: **operation chaining** and **fallback handling**.

## Directory Structure

```
operations/
├── orders/          # Order management operations
├── payments/        # Payment processing operations
├── products/        # Product operations (existing)
└── users/           # User operations (existing)
```

## Key Demonstrations

### 1. Operation Chaining with `.then`

**File:** `/workspaces/gems/typed_operation/test/dummy/app/operations/orders/create_order_operation.rb`

This demonstrates the most powerful feature of TypedOperation: composing multiple operations into a single, reusable chain.

```ruby
CreateOrderOperation = ValidateOrderOperation
  .then(CheckInventoryOperation)
  .then(CalculatePricingOperation)
  .then(CreateRecordOperation)
```

**How it works:**
1. Each operation accepts a `context` Hash as a positional parameter
2. Each operation returns `Success(context.merge(new_data))` to pass data forward
3. The chain automatically short-circuits on the first `Failure`
4. Data accumulates through the pipeline

**Usage:**
```ruby
result = Orders::CreateOrderOperation.call({
  user: current_user,
  items: [
    { product_id: 1, quantity: 2 },
    { product_id: 3, quantity: 1 }
  ],
  promo_code: "SAVE10"
})

if result.success?
  order = result.value![:order]
  total = result.value![:total]
  # Order created successfully!
else
  error_type, details = result.failure
  # Handle: :validation_error, :out_of_stock, etc.
end
```

**Chain Steps:**
1. **ValidateOrderOperation** - Validates user, items, quantities
2. **CheckInventoryOperation** - Checks stock availability
3. **CalculatePricingOperation** - Calculates subtotal, discounts, shipping, total
4. **CreateRecordOperation** - Creates Order and OrderItem records

### 2. Fallback Handling with `.or_else`

**File:** `/workspaces/gems/typed_operation/test/dummy/app/operations/payments/payment_with_fallback_operation.rb`

This demonstrates graceful degradation using a backup payment processor when the primary fails.

```ruby
PaymentWithFallback = ProcessPaymentOperation
  .or_else(ProcessViaBackupOperation)
```

**How it works:**
1. Attempts payment with primary processor
2. If primary fails, automatically tries backup processor
3. If primary succeeds, backup is never called
4. Returns whichever succeeds (or the final failure)

**Usage:**
```ruby
result = Payments::PaymentWithFallback.call(
  order: order,
  payment_method: "credit_card",
  card_token: "tok_visa"
)

if result.success?
  payment = result.value![:payment]

  if result.value![:fallback]
    # Used backup processor
    logger.warn "Primary payment processor failed, used backup"
  end
else
  error_type, message = result.failure
  # Both processors failed
end
```

**Simulated Behavior:**
- Primary processor fails for orders > $10,000
- Backup processor handles all amounts
- Payments are marked with `processor: "primary"` or `processor: "backup"`

## Order Operations

### Chainable Operations (used in CreateOrderOperation)

All these operations follow the chainable pattern:
- Accept: `positional_param :context, Hash`
- Return: `Success(context.merge(new_data))` or `Failure([:error_type, details])`

#### `Orders::ValidateOrderOperation`
Validates order data structure and business rules.

**Checks:**
- User exists
- Items array present and non-empty
- Each item has product_id and quantity > 0

**Errors:**
- `[:validation_error, "User is required"]`
- `[:validation_error, "Order must contain at least one item"]`
- `[:validation_error, "Item N missing product_id"]`
- `[:validation_error, "Item N must have quantity > 0"]`

#### `Orders::CheckInventoryOperation`
Verifies all items are in stock.

**Adds to context:**
- `inventory_checked: true`

**Errors:**
- `[:out_of_stock, { unavailable: [...] }]`

**Simulated behavior:**
- Products >= 9999: Out of stock
- Products 9000-9998: Limited stock (max 5)
- All others: Sufficient stock

#### `Orders::CalculatePricingOperation`
Calculates all pricing information.

**Adds to context:**
- `subtotal`: Sum of item prices
- `discount_percent`: Promo code discount percentage (0, 10, or 20)
- `discount_amount`: Dollar amount of discount
- `shipping_cost`: Shipping fee ($5.99 or $0)
- `total`: Final total

**Promo codes:**
- `SAVE10`: 10% off
- `SAVE20`: 20% off
- `FREESHIP`: Free shipping

**Shipping rules:**
- Free if subtotal >= $50
- Free with FREESHIP code
- Otherwise $5.99

#### `Orders::CreateRecordOperation`
Creates Order and OrderItem database records.

**Adds to context:**
- `order`: Complete order object with items

### Standalone Operations

#### `Orders::ListUserOrdersOperation`
Lists orders for a user with pagination.

**Parameters:**
- `user`: User object
- `page`: Integer (default: 1)
- `per_page`: Integer (default: 20, max: 100)

**Returns:**
```ruby
Success({
  orders: [...],
  total: 3,
  page: 1,
  per_page: 20,
  total_pages: 1
})
```

#### `Orders::CancelOrderOperation`
Cancels a pending order and releases inventory.

**Parameters:**
- `order`: Order object
- `reason`: Optional string

**Rules:**
- Only orders with status "pending" can be cancelled

**Errors:**
- `[:cannot_cancel, "Order cannot be cancelled. Current status: ..."]`

## Payment Operations

### `Payments::ValidatePaymentMethodOperation`
Validates payment method is supported.

**Parameters:**
- `payment_method`: String (credit_card, debit_card, paypal, apple_pay)
- `card_token`: Optional String (required for card methods)

**Errors:**
- `[:invalid_payment_method, "Payment method '...' is not supported"]`
- `[:invalid_payment_method, "credit_card requires a card_token"]`

### `Payments::ProcessPaymentOperation`
Primary payment processor.

**Parameters:**
- `order`: Order object
- `payment_method`: String
- `card_token`: Optional String

**Returns:**
```ruby
Success({
  payment: {...},
  transaction_id: "txn_...",
  order: updated_order
})
```

**Errors:**
- `[:payment_failed, "Order cannot be paid. Current status: ..."]`
- `[:payment_failed, "Payment declined. Amount exceeds limit."]` (> $10,000)

### `Payments::ProcessViaBackupOperation`
Backup payment processor (used in fallback chain).

Same interface as ProcessPaymentOperation, but:
- No amount limit
- Marks payment with `processor: "backup"`
- Returns `fallback: true` in success value

### `Payments::RefundOperation`
Refunds a completed payment.

**Parameters:**
- `payment`: Payment object
- `reason`: Optional String

**Rules:**
- Only payments with status "completed" can be refunded

**Errors:**
- `[:cannot_refund, "Payment cannot be refunded. Current status: ..."]`

## Design Patterns

### Context-Passing Pattern (for chainable operations)

```ruby
class MyChainableOperation < TypedOperation::Base
  include Dry::Monads[:result]

  positional_param :context, Hash

  def perform
    # Validate
    return Failure([:error_type, "message"]) if invalid?

    # Do work
    result = do_something(context)

    # Return context with new data
    Success(context.merge(my_result: result))
  end
end
```

### Error Tuple Pattern

Always return errors as `[:error_type, details]` tuples:

```ruby
Failure([:validation_error, "User is required"])
Failure([:out_of_stock, { unavailable: [...] }])
Failure([:payment_failed, "Amount exceeds limit"])
```

This makes error handling consistent and programmatic:

```ruby
result = operation.call(...)
if result.failure?
  error_type, details = result.failure
  case error_type
  when :validation_error
    # Handle validation
  when :out_of_stock
    # Handle inventory
  when :payment_failed
    # Handle payment
  end
end
```

## Testing Examples

```ruby
# Test the full order creation chain
def test_create_order_success
  user = { id: 1, email: "test@example.com" }

  result = Orders::CreateOrderOperation.call({
    user: user,
    items: [{ product_id: 1, quantity: 2 }],
    promo_code: "SAVE10"
  })

  assert result.success?
  assert_equal "pending", result.value![:order][:status]
  assert result.value![:total] < result.value![:subtotal]
end

# Test chain short-circuits on validation error
def test_create_order_invalid_items
  result = Orders::CreateOrderOperation.call({
    user: { id: 1 },
    items: [],
    promo_code: nil
  })

  assert result.failure?
  error_type, message = result.failure
  assert_equal :validation_error, error_type
end

# Test fallback payment processor
def test_payment_with_fallback_uses_backup_for_large_amount
  order = { id: 1, status: "pending", total: 15_000 }

  result = Payments::PaymentWithFallback.call(
    order: order,
    payment_method: "credit_card",
    card_token: "tok_visa"
  )

  assert result.success?
  assert_equal true, result.value![:fallback]
  assert_equal "backup", result.value![:payment][:processor]
end
```

## Real-World Usage

In a Rails controller:

```ruby
class OrdersController < ApplicationController
  def create
    result = Orders::CreateOrderOperation.call(
      user: current_user,
      items: params[:items],
      promo_code: params[:promo_code]
    )

    if result.success?
      order = result.value![:order]

      # Now process payment
      payment_result = Payments::PaymentWithFallback.call(
        order: order,
        payment_method: params[:payment_method],
        card_token: params[:card_token]
      )

      if payment_result.success?
        redirect_to order_path(order), notice: "Order placed successfully!"
      else
        error_type, message = payment_result.failure
        redirect_to cart_path, alert: "Payment failed: #{message}"
      end
    else
      error_type, message = result.failure
      redirect_to cart_path, alert: "Order invalid: #{message}"
    end
  end
end
```

## Benefits of This Approach

1. **Composability**: Build complex workflows from simple, reusable operations
2. **Testability**: Each operation can be tested in isolation
3. **Maintainability**: Clear separation of concerns
4. **Readability**: Self-documenting pipeline of steps
5. **Error Handling**: Consistent error tuples throughout
6. **Type Safety**: TypedOperation validates parameters
7. **Railway-Oriented Programming**: Automatic success/failure path handling

---
title: Examples
nav_order: 2
---

Comprehensive examples demonstrating TypedOperation features.

## Complete Operation Example

```ruby
class ShelveBookOperation < ::TypedOperation::Base
  # Parameters can be specified with `positional_param`/`named_param` or directly with the
  # underlying `param` method.
  
  # Note that you may also like to simply alias the param methods to your own preferred names:
  # `positional`/`named` or `arg`/`key` for example.
  
  # A positional parameter (positional argument passed to the operation when creating it).
  positional_param :title, String
  # Or if you prefer:
  #   `param :title, String, positional: true`
  
  # A named parameter (keyword argument passed to the operation when creating it).
  named_param :description, String
  # Or if you prefer:
  #   `param :description, String`

  # `param` creates named parameters by default
  param :author_id, Integer, &:to_i
  param :isbn, String
  
  # Optional parameters are specified by wrapping the type constraint in the `optional` method, or using the `optional:` option
  param :shelf_code, optional(Integer)
  # Or if you prefer:
  #   `named_param :shelf_code, Integer, optional: true`

  param :category, String, default: "unknown".freeze

  # optional hook called when the operation is initialized, and after the parameters have been set
  def prepare
    raise ArgumentError, "ISBN is invalid" unless valid_isbn?
  end

  # optionally hook in before execution ... and call super to allow subclasses to hook in too
  def before_execute_operation
    # ...
    super
  end

  # The 'work' of the operation, this is the main body of the operation and must be implemented
  def perform
    "Put away '#{title}' by author ID #{author_id}#{shelf_code ? " on shelf #{shelf_code}" : "" }"
  end

  # optionally hook in after execution ... and call super to allow subclasses to hook in too
  def after_execute_operation(result)
    # ...
    super
  end
  
  private

  def valid_isbn?
    # ...
    true
  end
end

shelve = ShelveBookOperation.new("The Hobbit", description: "A book about a hobbit", author_id: "1", isbn: "978-0261103283")
# => #<ShelveBookOperation:0x0000000108b3e490 @attributes={:title=>"The Hobbit", :description=>"A book about a hobbit", :author_id=>1, :isbn=>"978-0261103283", :shelf_code=>nil, :category=>"unknown"}, ...

shelve.call
# => "Put away 'The Hobbit' by author ID 1"

shelve = ShelveBookOperation.with("The Silmarillion", description: "A book about the history of Middle-earth", shelf_code: 1)
# => #<TypedOperation::PartiallyApplied:0x0000000103e6f560 ...

shelve.call(author_id: "1", isbn: "978-0261102736")
# => "Put away 'The Silmarillion' by author ID 1 on shelf 1"

curried = shelve.curry
# => #<TypedOperation::Curried:0x0000000108d98a10 ...

curried.(1).("978-0261102736")
# => "Put away 'The Silmarillion' by author ID 1 on shelf 1"

shelve.call(author_id: "1", isbn: false)
# => Raises an error because isbn is invalid
# :in `initialize': Expected `false` to be of type: `String`. (Literal::TypeError)
```

### Partially applying parameters

Operations can also be partially applied and curried:

```ruby
class TestOperation < ::TypedOperation::Base
  param :foo, String, positional: true
  param :bar, String
  param :baz, String, &:to_s

  def perform = "It worked! (#{foo}, #{bar}, #{baz})"
end

# Invoking the operation directly
TestOperation.("1", bar: "2", baz: 3)
# => "It worked! (1, 2, 3)"

# Partial application of parameters
partially_applied = TestOperation.with("1").with(bar: "2")
# => #<TypedOperation::PartiallyApplied:0x0000000110270248 @keyword_args={:bar=>"2"}, @operation_class=TestOperation, @positional_args=["1"]>

# You can partially apply more than one parameter at a time, and chain calls to `.with`.
# With all the required parameters set, the operation is 'prepared' and can be instantiated and called
prepared = TestOperation.with("1", bar: "2").with(baz: 3)
# => #<TypedOperation::Prepared:0x0000000110a9df38 @keyword_args={:bar=>"2", :baz=>3}, @operation_class=TestOperation, @positional_args=["1"]>

# A 'prepared' operation can instantiated & called
prepared.call
# => "It worked! (1, 2, 3)"

# You can provide additional parameters when calling call on a partially applied operation
partially_applied.call(baz: 3)
# => "It worked! (1, 2, 3)"

# Partial application can be done using `.with or `.[]`
TestOperation.with("1")[bar: "2", baz: 3].call
# => "It worked! (1, 2, 3)"

# Currying an operation, note that *all required* parameters must be provided an argument in order  
TestOperation.curry.("1").("2").(3)
# => "It worked! (1, 2, 3)"

# You can also curry from an already partially applied operation, so you can set optional named parameters first.
# Note currying won't let you set optional positional parameters.
partially_applied = TestOperation.with("1")
partially_applied.curry.("2").(3)
# => "It worked! (1, 2, 3)"

# > TestOperation.with("1").with(bar: "2").call
# => Raises an error because it is PartiallyApplied and so can't be called (it is missing required args)
#      "Cannot call PartiallyApplied operation TestOperation, are you expecting it to be Prepared? (TypedOperation::MissingParameterError)"

TestOperation.with("1").with(bar: "2").with(baz: 3).operation
# same as > TestOperation.new("1", bar: "2", baz: 3)
# => <TestOperation:0x000000014a0048a8 ...>

# > TestOperation.with(foo: "1").with(bar: "2").operation
# => Raises an error because it is PartiallyApplied so operation can't be instantiated
#      "Cannot instantiate Operation TestOperation, as it is only partially applied. (TypedOperation::MissingParameterError)"
```

---

## Dummy App Examples

The following examples are from the test dummy Rails application included in the gem's source code. You can find these files in `test/dummy/app/operations/` and run them in the dummy app context.

### ApplicationOperation (Base Class)

A minimal base class using built-in Result types:

```ruby
# test/dummy/app/operations/application_operation.rb
class ApplicationOperation < TypedOperation::Base
  include TypedOperation::Result::Mixin
end
```

### Simple Operation with Result Types

A standalone operation demonstrating Success/Failure returns:

```ruby
# test/dummy/app/operations/products/create_operation.rb
module Products
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
```

### Pipeline with Multiple Operations

A complete order processing pipeline demonstrating:
- Named steps
- Conditional steps (`if:` option)
- Transform blocks
- Multiple operations working together

```ruby
# test/dummy/app/operations/orders/process_order_pipeline.rb
module Orders
  ProcessOrderPipeline = TypedOperation::Pipeline.build do
    step :validate, ValidateOrderParams
    step :check_stock, CheckProductStock, if: ->(ctx) { !ctx[:skip_stock_check] }
    transform do |ctx|
      ctx.merge(total: ctx[:product].price * ctx[:quantity])
    end
    step :create_order, CreateOrderRecord
  end
end
```

#### Step 1: ValidateOrderParams

Validates input and fetches associated records:

```ruby
# test/dummy/app/operations/orders/validate_order_params.rb
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
```

#### Step 2: CheckProductStock

Verifies sufficient inventory (conditionally skipped):

```ruby
# test/dummy/app/operations/orders/check_product_stock.rb
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
```

#### Step 3: CreateOrderRecord

Creates the order record and reserves stock:

```ruby
# test/dummy/app/operations/orders/create_order_record.rb
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
```

### Using the Pipeline

```ruby
# Process an order
result = Orders::ProcessOrderPipeline.call(
  user_id: 1,
  product_id: 42,
  quantity: 2
)

case result
in Success[order:]
  puts "Order created: #{order.id}"
in Failure[error: :insufficient_stock, available:]
  puts "Only #{available} items in stock"
in Failure[error:]
  puts "Failed: #{error}"
end

# Skip stock check (e.g., for backorders)
result = Orders::ProcessOrderPipeline.call(
  user_id: 1,
  product_id: 42,
  quantity: 100,
  skip_stock_check: true
)
```
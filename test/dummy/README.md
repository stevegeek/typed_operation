# TypedOperation Demo: Pen Shop API

A minimal Rails API demonstrating TypedOperation patterns.

## Models

- `User` - email, name, role
- `Product` - name, price, pen_type, stock_quantity
- `Order` - user, product, quantity, total, status

## Operations

```
app/operations/
├── application_operation.rb
├── orders/
│   ├── check_product_stock.rb
│   ├── create_order_record.rb
│   ├── process_order_pipeline.rb   # Pipeline DSL example
│   └── validate_order_params.rb
└── products/
    └── create_operation.rb          # Simple standalone example
```

### Simple Standalone Operation

```ruby
# app/operations/products/create_operation.rb
class CreateOperation < ApplicationOperation
  param :name, String
  param :price, Numeric
  param :pen_type, String
  param :stock_quantity, Integer, default: 0

  def perform
    product = Product.new(name:, price:, pen_type:, stock_quantity:)
    product.save ? Success(product:) : Failure(errors: product.errors.full_messages)
  end
end
```

### Composition Chain (inline in controller)

```ruby
# app/controllers/orders_controller.rb
def create
  result = Orders::ValidateOrderParams
    .then(Orders::CheckProductStock)
    .then(Orders::CreateOrderRecord)
    .call(**order_params)

  case result
  in Success(order:)
    render json: order, status: :created
  in Failure(error: :insufficient_stock, available:)
    render json: {error: "Insufficient stock", available:}, status: :unprocessable_entity
  end
end
```

### Pipeline DSL

```ruby
# app/operations/orders/process_order_pipeline.rb
ProcessOrderPipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateOrderParams
  step :check_stock, CheckProductStock, if: ->(ctx) { !ctx[:skip_stock_check] }
  transform do |ctx|
    ctx.merge(total: ctx[:product].price * ctx[:quantity])
  end
  step :create_order, CreateOrderRecord
end
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/products` | GET | List products |
| `/products` | POST | Create product |
| `/orders` | GET | List orders |
| `/orders` | POST | Create order (composition chain) |
| `/orders/via_pipeline` | POST | Create order (pipeline) |

## Running Tests

```bash
bundle exec ruby -Itest test/typed_operation/dummy_app_test.rb
```

---
title: Pipelines
nav_order: 1
---

# Pipelines

Pipelines provide a declarative DSL for building multi-step operation workflows. They are syntactic sugar over the composition/chaining system, adding named steps, conditional execution, and structured error handling.

## Basic Usage

### Creating a Pipeline

Use `TypedOperation::Pipeline.build` with a block to define steps:

```ruby
pipeline = TypedOperation::Pipeline.build do
  step ValidateInput
  step TransformData
  step SaveRecord
  step SendNotification
end

result = pipeline.call(input: "data")
```

Empty pipelines return the input unchanged wrapped in `Success`:

```ruby
empty = TypedOperation::Pipeline.build { }
empty.call(foo: "bar")  # => Success(foo: "bar")
```

### Named Steps

Name your steps for better introspection and error messages:

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateOrderParams
  step :check_stock, CheckProductStock
  step :create_order, CreateOrderRecord
  step :notify, SendOrderConfirmation
end
```

## DSL Methods

### step(name?, operation, if: nil)

Add an operation to the pipeline. Steps execute sequentially on the success track.

```ruby
# Unnamed step (name derived from class)
step ValidateUser

# Named step
step :validate, ValidateUser

# Conditional step
step :notify, SendEmail, if: ->(ctx) { ctx[:user_type] == "premium" }
```

Conditional steps receive the current context and are only executed if the condition returns truthy. When a condition returns false, the step is skipped and the context passes through unchanged (returns `Success(context)`).

### transform(&block)

Transform the context without calling an operation. The block receives the current context hash and returns a new context. Result is automatically wrapped in `Success`.

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :fetch_product, FetchProduct
  transform do |ctx|
    ctx.merge(total: ctx[:product].price * ctx[:quantity])
  end
  step :create_order, CreateOrder
end
```

### fallback(operation, &block) / or_else(operation, &block)

Provide error recovery. Only executed if a previous step fails. `fallback` and `or_else` are aliases for the same functionality.

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :charge_card, ChargeCard
  fallback ProcessViaBackup
end

# With block
pipeline = TypedOperation::Pipeline.build do
  step :risky_operation, RiskyOperation
  or_else do |failure|
    Dry::Monads::Success(recovered: true, error: failure)
  end
end
```

### on_failure(&block)

Define a failure handler for the entire pipeline. Called with the failure value and step name when any step fails. The handler's return value becomes the final result. If the handler itself fails, that failure is returned.

Note: `on_failure` does not run if a `fallback` successfully handles the failure (fallback recovers before `on_failure` would trigger).

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateOrder
  step :process, ProcessOrder

  on_failure do |error, step_name|
    Dry::Monads::Failure([:pipeline_failed, {
      step: step_name,
      error: error,
      timestamp: Time.current
    }])
  end
end
```

## Pipeline Methods

### #call(*args, **kwargs)

Execute the pipeline. Arguments are passed to the first step.

```ruby
result = pipeline.call(input: "data")
```

### #steps

Introspect the pipeline's steps. Returns an array of step hashes. Steps can have `type: :step`, `type: :transform`, or `type: :fallback`.

```ruby
pipeline.steps
# => [
#   {type: :step, name: :validate, operation: ValidateOp, condition: nil},
#   {type: :step, name: :process, operation: ProcessOp, condition: #<Proc>},
#   {type: :transform, name: :transform_1, ...},
#   {type: :fallback, name: :fallback_1, operation: RecoveryOp, ...}
# ]

pipeline.steps.map { |s| s[:name] }  # => [:validate, :process, :transform_1, :fallback_1]
```

### #append(operation, name: nil, if: nil)

Add a step to an existing pipeline, returning a new pipeline instance.

```ruby
extended_pipeline = pipeline.append(
  SendNotification,
  name: :notify,
  if: ->(ctx) { ctx[:should_notify] }
)
```

### #compose(other, on_failure: nil)

Merge two pipelines into one. Both pipelines' steps are combined.

```ruby
validation_pipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateInput
  step :transform, TransformData
end

persistence_pipeline = TypedOperation::Pipeline.build do
  step :save, SaveRecord
  step :notify, SendNotification
end

full_pipeline = validation_pipeline.compose(persistence_pipeline)
```

If both pipelines have failure handlers, specify which to use:

```ruby
full_pipeline = left.compose(right, on_failure: :left)   # Use left handler
full_pipeline = left.compose(right, on_failure: :right)  # Use right handler
full_pipeline = left.compose(right, on_failure: ->(err, step) { ... })  # Custom
```

### #+(other)

Smart composition operator. Merges pipelines or appends operations.

```ruby
# Compose two pipelines
full = validation_pipeline + persistence_pipeline

# Append an operation
extended = pipeline + NotifyOperation
```

### #to_chain

Convert the pipeline to a chainable wrapper to access full composition flexibility (`.then`, `.or_else`, `.transform`, etc.). Pipelines don't include the Composition module directly, so use `to_chain` when you need these methods.

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateInput
  step :process, ProcessData
end

chain = pipeline.to_chain
  .then(SaveRecord)
  .or_else(HandleFailure)

result = chain.call(input: "data")
```

## Context Flow

Pipelines accumulate context across steps. Each step receives the merged context from all previous steps.

### Hash Context

When operations return hashes, they are merged into the context:

```ruby
class Step1 < TypedOperation::Base
  param :input, String
  def perform
    Success(step1_result: input.upcase)
  end
end

class Step2 < TypedOperation::Base
  param :input, String
  param :step1_result, String
  def perform
    Success(step2_result: "#{input} - #{step1_result}")
  end
end

pipeline = TypedOperation::Pipeline.build do
  step Step1
  step Step2
end

result = pipeline.call(input: "hello")
result.value!
# => {input: "hello", step1_result: "HELLO", step2_result: "hello - HELLO"}
```

### Context Objects

Pipelines work seamlessly with `TypedOperation::Context` objects:

```ruby
class ContextAwareOp < TypedOperation::Base
  positional_param :ctx, TypedOperation::Context

  def perform
    Success(TypedOperation::Context.new(
      user: ctx.user,
      validated: true
    ))
  end
end

ctx = TypedOperation::Context.new(user: "alice")
result = pipeline.call(ctx)
```

### Positional vs Keyword Parameters

Pipelines intelligently handle both parameter styles:

```ruby
# Positional operation (receives full context hash as single arg)
class PositionalOp < TypedOperation::Base
  positional_param :context, Hash
  def perform
    Success(context.merge(processed: true))
  end
end

# Keyword operation (context spread as **kwargs)
class KeywordOp < TypedOperation::Base
  param :user, String
  param :processed, _Boolean
  def perform
    Success(result: "#{user} was processed")
  end
end

pipeline = TypedOperation::Pipeline.build do
  step PositionalOp  # Receives full context
  step KeywordOp     # Receives extracted params
end
```

## Railway-Oriented Programming

Pipelines implement the railway-oriented programming pattern with two tracks:

- **Success Track**: Steps execute sequentially as long as each returns `Success`
- **Failure Track**: First `Failure` short-circuits remaining steps

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :step1, Op1  # Success -> continues
  step :step2, Op2  # Failure -> jumps to failure track
  step :step3, Op3  # Skipped
  fallback RecoveryOp  # Executes on failure track
end
```

Visual representation:

```
Input
  |
  v
[Step 1] --Success--> [Step 2] --Success--> [Step 3] --Success--> Success
  |                      |                     |
  Failure                Failure               Failure
  |                      |                     |
  +----------------------+---------------------+
                         |
                         v
                    [Fallback] ---> Final Result
```

## Real-World Example

Basic order processing pipeline:

```ruby
module Orders
  ProcessOrderPipeline = TypedOperation::Pipeline.build do
    step :validate, ValidateOrderParams
    step :charge_payment, ChargePayment
    step :create_order, CreateOrderRecord
    step :send_confirmation, SendOrderEmail
  end
end

result = Orders::ProcessOrderPipeline.call(
  product_id: 123,
  quantity: 2,
  customer_id: 456
)
```

Adding error handling with fallback and failure handler:

```ruby
ProcessOrderPipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateOrderParams
  step :charge_payment, ChargePayment
  fallback ChargeBackupPaymentGateway  # Retry with backup if payment fails
  step :create_order, CreateOrderRecord
  step :send_confirmation, SendOrderEmail

  on_failure do |error, step_name|
    Rails.logger.error("Order failed at #{step_name}: #{error}")
    Dry::Monads::Failure([:order_failed, step: step_name, error: error])
  end
end
```

## When to Use Pipelines vs Chaining

### Use Pipelines When:

- Building multi-step workflows with 3+ operations
- You need named steps for debugging/monitoring
- Conditional execution is required
- You want centralized error handling with step attribution
- The workflow is relatively stable and declarative

### Use Chaining When:

- Composing 2-3 operations dynamically
- You need fine-grained control over argument passing
- Operations have complex parameter transformations
- Building reusable operation fragments
- Composition logic is conditional at runtime

### Example Comparison

**Pipeline approach** (declarative, named steps):

```ruby
pipeline = TypedOperation::Pipeline.build do
  step :validate, ValidateUser
  step :create, CreateUser
  step :send_email, SendWelcome

  on_failure { |err, step| log_error(step, err) }
end

result = pipeline.call(email: "user@example.com")
```

**Chaining approach** (flexible, explicit):

```ruby
chain = ValidateUser
  .with(email: "user@example.com")
  .then(CreateUser)
  .then { |ctx| SendWelcome.with(user: ctx[:user]) }
  .or_else { |failure| handle_failure(failure) }

result = chain.call
```

Both approaches work with the same operations. Choose based on your needs for declarativeness vs flexibility.

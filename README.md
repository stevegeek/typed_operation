# TypedOperation

![Coverage](badges/coverage_badge_total.svg)
![RubyCritic](badges/rubycritic_badge_score.svg)

A Command pattern implementation for Ruby with typed parameters, partial application, and operation composition.

## Why TypedOperation?

- **Type-safe parameters** - Runtime validation using the [`literal`](https://github.com/joeldrapper/literal) gem
- **Partial application & currying** - Build specialized operations from general ones
- **Operation composition** - Chain operations together with `.then`, pipelines, and railway-oriented error handling
- **Result types** - Built-in Success/Failure types, or use [`Dry::Monads`](https://dry-rb.org/gems/dry-monads/)
- **Rails integration** - Generators and Action Policy authorization support

## Installation

Add to your Gemfile:

```ruby
gem "typed_operation"
```

For Rails, generate the base operation class:

```bash
bin/rails g typed_operation:install

# With optional integrations
bin/rails g typed_operation:install --dry_monads --action_policy
```

## Quick Start

```ruby
class GreetUser < TypedOperation::Base
  param :name, String
  param :greeting, String, default: "Hello"

  def perform
    "#{greeting}, #{name}!"
  end
end

# Direct invocation
GreetUser.call(name: "World")
# => "Hello, World!"

# Partial application
greeter = GreetUser.with(greeting: "Welcome")
greeter.call(name: "Alice")
# => "Welcome, Alice!"
```

### Parameters

```ruby
class CreatePost < TypedOperation::Base
  # Positional parameter
  positional_param :title, String

  # Named parameters (keyword arguments)
  param :body, String
  param :author, User

  # Optional with default
  param :status, String, default: "draft"

  # Type coercion
  param :view_count, Integer, &:to_i

  def perform
    Post.create!(title: title, body: body, author: author, status: status)
  end
end

CreatePost.call("My Post", body: "Content", author: current_user)
```

### Operation Composition

Chain operations using `.then`, `.transform`, and `.or_else`:

```ruby
ValidateOrder
  .then(ProcessPayment)
  .then(SendConfirmation)
  .or_else { |failure| LogError.call(failure) }
  .call(order_id: 123)
```

Or use the Pipeline DSL for declarative composition:

```ruby
OrderPipeline = TypedOperation::Pipeline.build do
  step ValidateOrder
  step ProcessPayment
  step SendConfirmation, if: ->(ctx) { ctx[:send_email] }
  on_failure { |error| Logger.error(error) }
end

OrderPipeline.call(order_id: 123, send_email: true)
```

### Result Types

TypedOperation includes built-in `Success`/`Failure` types for explicit error handling:

```ruby
class ProcessPayment < TypedOperation::Base
  include TypedOperation::Result::Mixin  # Built-in, no dependencies

  param :amount, Numeric

  def perform
    result = PaymentGateway.charge(amount)
    result.ok? ? Success(result.id) : Failure(:payment_failed)
  end
end

result = ProcessPayment.call(amount: 100)
result.success?  # => true/false
result.value!    # => the value (raises on failure)
```

For advanced features like Do notation, use [Dry::Monads](https://dry-rb.org/gems/dry-monads/) instead. See [Getting Started: Error Handling](website/docs/getting-started.md#error-handling) for details.

## Documentation

For complete documentation, visit the [TypedOperation documentation site](https://stevegeek.github.io/typed_operation/) or see the `website/docs/` directory:

- [Getting Started](website/docs/getting-started.md) - Installation and basic usage
- [API Reference](website/docs/api.md) - Complete API documentation
- [Pipelines](website/docs/pipelines.md) - Pipeline DSL and operation composition
- [Integrations](website/docs/integrations.md) - Rails, Dry::Monads, and Action Policy
- [Instrumentation](website/docs/instrumentation.md) - Debugging and tracing operations
- [Best Practices](website/docs/best-practices.md) - Patterns and recommendations
- [Examples](website/docs/examples.md) - Comprehensive code examples

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stevegeek/typed_operation.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TypedOperation project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/stevegeek/typed_operation/blob/master/CODE_OF_CONDUCT.md).

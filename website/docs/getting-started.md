---
layout: default
title: Getting Started
nav_order: 2
permalink: /getting-started
---

# Getting Started
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

A comprehensive guide to TypedOperation covering all core concepts.

## Installation

Add to your Gemfile:

```ruby
gem "typed_operation"
```

For Rails, run the generator to create an ApplicationOperation:

```bash
bin/rails g typed_operation:install
```

## Your First Operation

```ruby
class GreetUser < TypedOperation::Base
  param :name, String
  param :greeting, String, default: "Hello"

  def perform
    "#{greeting}, #{name}!"
  end
end

# Call directly
GreetUser.call(name: "Alice")
# => "Hello, Alice!"

# Or instantiate then call
operation = GreetUser.new(name: "Bob", greeting: "Hi")
operation.call
# => "Hi, Bob!"
```

Every operation must implement the `perform` method, which contains your business logic.

## Defining Operations

### Base Classes

TypedOperation provides two base classes:

| Class | Backed By | Mutability | ActionPolicy |
|-------|-----------|------------|--------------|
| `TypedOperation::Base` | `Literal::Struct` | Mutable | ✓ Supported |
| `TypedOperation::ImmutableBase` | `Literal::Data` | Frozen | ✗ Not supported |

Use `ImmutableBase` when you want stronger immutability guarantees.

### Lifecycle Hooks

Operations provide hooks for setup, validation, and result processing:

```ruby
class ProcessPayment < TypedOperation::Base
  param :order, Order
  param :amount, Integer

  def prepare
    raise ArgumentError, "Order already paid" if order.paid?
  end

  def before_execute_operation
    @start_time = Time.current
    super
  end

  def perform
    PaymentGateway.charge(amount: amount, order_id: order.id)
  end

  def after_execute_operation(result)
    Rails.logger.info "Payment processed in #{Time.current - @start_time}s"
    super
  end
end
```

**Key points:**
- `prepare` - Called after initialization; use for validation
- `before_execute_operation` - Called before `perform`
- `after_execute_operation(result)` - Called after `perform`; return value becomes operation result
- Call `super` in hooks when you want subclasses to be able to hook in
- Exceptions from hooks propagate to the caller

See [API Reference: Lifecycle Hooks](api#lifecycle-hooks) for complete documentation.

## Parameters

### Basic Definition

```ruby
class CreateUser < TypedOperation::Base
  param :email, String                    # Required
  param :role, String, default: "member"  # With default
  param :bio, optional(String)            # Optional (can be nil)

  def perform
    User.create!(email:, role:, bio:)
  end
end
```

### Positional vs Named Parameters

```ruby
class SendEmail < TypedOperation::Base
  positional_param :recipient, String     # Positional argument
  param :subject, String                  # Keyword argument
  param :body, String

  def perform
    EmailService.send(to: recipient, subject:, body:)
  end
end

# Usage: positional first, then keywords
SendEmail.call("user@example.com", subject: "Welcome", body: "Thanks!")
```

### Type Constraints

TypedOperation uses the [literal](https://literal.fun) gem for type checking:

```ruby
class Example < TypedOperation::Base
  include Literal::Types

  param :name, String
  param :count, Integer
  param :active, _Boolean
  param :tags, _Array(String)
  param :data, _Hash(String, Integer)
  param :status, _Enum("pending", "active", "closed")
  param :user, _Nilable(User)
  param :id, _Union(Integer, String)
end
```

Types are checked at instantiation. Invalid types raise `Literal::TypeError`.

### Parameter Coercion

Transform input values using `&:method` or a block:

```ruby
class Calculate < TypedOperation::Base
  param :count, Integer, &:to_i
  param :price, Float, &:to_f
  param :tags, _Array(String) do |value|
    value.is_a?(String) ? value.split(",").map(&:strip) : value
  end

  def perform
    # count and tags are coerced before type checking
  end
end

Calculate.call(count: "42", price: "19.99", tags: "ruby, rails")
# count = 42, price = 19.99, tags = ["ruby", "rails"]
```

## Executing Operations

### Multiple Ways to Execute

```ruby
# Class-level call (most common)
GreetUser.call(name: "Alice")

# Instantiate then call
op = GreetUser.new(name: "Alice")
op.call
```

### Using Operations in Blocks

```ruby
class Double < TypedOperation::Base
  param :n, Integer
  def perform; n * 2; end
end

[1, 2, 3].map { |n| Double.call(n: n) }
# => [2, 4, 6]
```

## Partial Application

Fix some parameters while leaving others open:

```ruby
class SendEmail < TypedOperation::Base
  param :to, String
  param :from, String
  param :subject, String
  param :body, String

  def perform
    EmailService.send(to:, from:, subject:, body:)
  end
end

# Create a reusable template
noreply = SendEmail.with(from: "noreply@example.com")

# Use it multiple times
noreply.call(to: "user@example.com", subject: "Welcome", body: "Thanks!")
noreply.call(to: "other@example.com", subject: "Update", body: "News...")
```

### Chaining .with Calls

```ruby
calc = SomeOperation.with(x: 10).with(y: 20).with(z: 30)
calc.call
```

### PartiallyApplied vs Prepared

- **PartiallyApplied**: Missing required parameters. Call raises `MissingParameterError`.
- **Prepared**: All required parameters set. Ready to call.

```ruby
partial = MyOp.with(a: 1)        # Missing required 'b'
partial.prepared?                # => false
partial.call(b: 2)               # Provide remaining params

prepared = MyOp.with(a: 1, b: 2)
prepared.prepared?               # => true
prepared.call                    # Execute immediately
```

Type checking is deferred until the operation is instantiated (when calling).

### Currying

Transform an operation into single-argument functions:

```ruby
class Add < TypedOperation::Base
  param :a, Integer
  param :b, Integer
  param :c, Integer
  def perform; a + b + c; end
end

Add.curry.(10).(20).(30)
# => 60
```

## Pattern Matching

TypedOperation supports Ruby 3+ pattern matching:

```ruby
class UserOp < TypedOperation::Base
  param :name, String
  param :role, String
  def perform; {name:, role:}; end
end

op = UserOp.new(name: "Alice", role: "admin")

case op
in UserOp[name:, role: "admin"]
  puts "Admin: #{name}"
in UserOp[name:, role:]
  puts "User: #{name} (#{role})"
end
```

### Matching Results (with Dry::Monads)

```ruby
result = CreateUser.call(email: "test@example.com")

case result
in Success(user)
  puts "Created: #{user.email}"
in Failure[:validation, errors]
  puts "Errors: #{errors.join(', ')}"
in Failure[code, message]
  puts "Failed: #{code} - #{message}"
end
```

## Error Handling

TypedOperation supports two approaches: exceptions for unexpected errors, and Result types for expected failures.

### Built-in Result Types (Default)

TypedOperation includes built-in `Success` and `Failure` types that work without additional dependencies:

```ruby
class CreateUser < TypedOperation::Base
  include TypedOperation::Result::Mixin

  param :email, String

  def perform
    return Failure(:invalid_email) unless email.include?("@")
    Success(User.create!(email:))
  end
end

result = CreateUser.call(email: "test@example.com")
result.success?  # => true
result.value!    # => the user (raises UnwrapError on failure)
result.failure   # => nil (or the error on failure)
```

The built-in types support pattern matching:

```ruby
case result
in TypedOperation::Result::Success[user]
  puts "Created: #{user.email}"
in TypedOperation::Result::Failure[error]
  puts "Failed: #{error}"
end
```

### Using Dry::Monads (Optional)

For more features like Do notation, use [Dry::Monads](https://dry-rb.org/gems/dry-monads/). You have two options:

**Option 1: Include Dry::Monads directly** (simplest, per-operation):

```ruby
class CreateUser < TypedOperation::Base
  include Dry::Monads[:result]

  def perform
    # Success/Failure come from Dry::Monads
  end
end
```

**Option 2: Configure the adapter globally** (use with `Result::Mixin`):

```ruby
# In an initializer
TypedOperation.configure do |config|
  config.result_adapter = :dry_monads
end

# Then in operations
class CreateUser < TypedOperation::Base
  include TypedOperation::Result::Mixin  # Now returns Dry::Monads types

  def perform
    # Success/Failure are now Dry::Monads types
  end
end
```

See [Integrations: Dry::Monads](integrations#drymonads) for Do notation and advanced patterns.

See [Best Practices](best-practices#error-handling) for detailed strategies.

## Debugging

### Enabling .explain

Include `TypedOperation::Explainable` in your base operation:

```ruby
class ApplicationOperation < TypedOperation::Base
  include TypedOperation::Explainable
end
```

### Using .explain

Use `.explain` instead of `.call` to trace execution:

```ruby
FulfillOrder.explain(order_id: 42)
# Output:
# FulfillOrder [1.23ms] ✓
# ├── ValidateOrder [0.15ms] ✓
# └── ProcessPayment [0.89ms] ✓
# => "Order 42 fulfilled"
```

Failures are marked with ✗ and show the error message.

### Introspection

Query operation metadata at runtime:

```ruby
MyOperation.positional_parameters        # => [:arg1, :arg2]
MyOperation.keyword_parameters           # => [:name, :email]
MyOperation.required_keyword_parameters  # => [:email]
MyOperation.optional_keyword_parameters  # => [:name]

partial = MyOperation.with(email: "test@example.com")
partial.prepared?  # => true/false
```

## Integrations Overview

### Rails

```bash
# Generate operations
bin/rails g typed_operation CreateUser email:string name:string
```

See [Integrations](integrations#rails) for full details.

### Dry::Monads

```ruby
class CreateUser < ApplicationOperation
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)

  param :email, String

  def perform
    user = yield validate_email
    yield send_welcome_email(user)
    Success(user)
  end
end
```

See [Integrations](integrations#drymonads) for full details.

### ActionPolicy

```ruby
class DeletePost < ApplicationOperation
  include TypedOperation::ActionPolicyAuth

  param :post, Post
  param :current_user, User

  authorized_via :current_user, :post, to: :destroy?

  def perform
    post.destroy!
  end
end
```

See [Integrations](integrations#actionpolicy) for full details.

## Next Steps

- [API Reference](api) - Complete method documentation
- [Integrations](integrations) - Rails, Dry::Monads, ActionPolicy details
- [Best Practices](best-practices) - Testing, error handling, patterns
- [Examples](examples) - Comprehensive code examples

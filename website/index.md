---
layout: home
title: Introduction
nav_order: 1
permalink: /
---

# TypedOperation
{: .fs-9 }

A Command Pattern implementation for Ruby with typed parameters, partial application, and currying
{: .fs-6 .fw-300 }

## What is TypedOperation?

TypedOperation is a Ruby gem that provides an elegant implementation of the Command pattern with:

- **Typed Parameters** - Define operation inputs with type constraints using the `literal` gem
- **Partial Application** - Partially apply parameters and curry operations
- **Callable** - Operations are callable objects that can be used with `.call`
- **Pattern Matching** - Deconstruct operations using Ruby's pattern matching
- **Rails Integration** - Generators and seamless Rails integration
- **Dry::Monads Support** - First-class support for Result types and Do notation
- **ActionPolicy Integration** - Built-in authorization with action_policy gem

## Why use TypedOperation?

- **Type Safety**: Catch parameter type errors early with runtime type checking
- **Composability**: Build complex operations from simpler ones using partial application
- **Testability**: Operations are isolated, easy-to-test units of business logic
- **Flexibility**: Choose your own result type (Dry::Monads, plain Ruby, etc.)
- **Maintainability**: Organize business logic in a consistent, predictable way

## Design Philosophy

TypedOperation follows these principles:

1. **Explicit is better than implicit** - Parameter types and requirements are clearly declared
2. **Composability over complexity** - Build complex operations from simple, reusable pieces
3. **Flexibility over prescription** - Choose your own result types and patterns
4. **Integration over isolation** - Work seamlessly with the Ruby ecosystem

## Quick Example

```ruby
class ShelveBookOperation < TypedOperation::Base
  # Positional parameter
  positional_param :title, String

  # Named parameters with type constraints
  param :author_id, Integer, &:to_i
  param :isbn, String

  # Optional parameters
  param :shelf_code, optional(Integer)
  param :category, String, default: "unknown"

  def perform
    "Put away '#{title}' by author ID #{author_id}" +
      (shelf_code ? " on shelf #{shelf_code}" : "")
  end
end

# Direct instantiation and call
ShelveBookOperation.new(
  "The Hobbit",
  author_id: "1",
  isbn: "978-0261103283"
).call
# => "Put away 'The Hobbit' by author ID 1"

# Partial application
shelve = ShelveBookOperation.with("The Silmarillion", shelf_code: 1)
shelve.call(author_id: "1", isbn: "978-0261102736")
# => "Put away 'The Silmarillion' by author ID 1 on shelf 1"

# Currying
curried = shelve.curry
curried.(1).("978-0261102736")
# => "Put away 'The Silmarillion' by author ID 1 on shelf 1"
```

## Core Features

### Typed Parameters

Define your operation's inputs with type constraints, making invalid states unrepresentable:

```ruby
class CreateUserOperation < TypedOperation::Base
  param :email, String
  param :age, Integer
  param :admin, _Boolean, default: false

  def perform
    # Type checking happens automatically
    User.create!(email: email, age: age, admin: admin)
  end
end
```

### Partial Application & Currying

Build reusable operation templates by fixing some parameters while leaving others open:

```ruby
# Partial application
send_email = SendEmailOperation.with(from: "noreply@example.com")
send_email.call(to: "user@example.com", subject: "Welcome!")

# Currying
curried = SendEmailOperation.curry
curried.("noreply@example.com").("user@example.com").("Welcome!")
```

### Rails Integration

Generate operations and integrate seamlessly with Rails:

```bash
bin/rails g typed_operation:install
bin/rails g typed_operation CreateUser
```

### Dry::Monads Support

Use Result types and Do notation for railway-oriented programming:

```ruby
class CreateUserOperation < ApplicationOperation
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)

  param :email, String

  def perform
    user = yield create_user(email)
    yield send_welcome_email(user)

    Success(user)
  end
end
```

### ActionPolicy Integration

Built-in authorization support:

```ruby
class UpdatePostOperation < ApplicationOperation
  include TypedOperation::ActionPolicyAuth

  param :initiator, User
  param :post, Post

  action_type :update
  authorized_via :initiator, record: :post

  def perform
    post.update!(title: "Updated")
  end
end
```

## Getting Started

Explore the documentation to learn more:

- [Getting Started](/docs/getting-started/)
- [API Reference](/docs/api/)
- [Integrations](/docs/integrations/)
- [Best Practices](/docs/best-practices/)
- [Examples](/docs/examples/)
- [Pipelines](/docs/pipelines/)
- [Instrumentation](/docs/instrumentation/)
- [Compared to Other Gems](/docs/similar-gems/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "typed_operation"
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install typed_operation
```

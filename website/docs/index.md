---
layout: default
title: Home
nav_order: 1
permalink: /
---

# TypedOperation

Command pattern with runtime type checking for Ruby.

## Features

- **Type-safe parameters** - Validated at instantiation via the [literal](https://github.com/joeldrapper/literal) gem
- **Partial application & currying** - Build operations incrementally
- **Pattern matching** - Full Ruby 3+ support with `deconstruct` and `deconstruct_keys`
- **Flexible results** - Return plain values, Dry::Monads, or custom objects
- **Framework-agnostic** - Works anywhere, optional Rails integration
- **Immutability options** - Choose `Base` (mutable) or `ImmutableBase` (frozen)

## Quick Start

Define operations with typed parameters and a `perform` method:

```ruby
class CreateUser < TypedOperation::Base
  param :email, String
  param :name, String
  param :role, String, default: "member"

  def perform
    User.create!(email:, name:, role:)
  end
end

# Call directly
CreateUser.call(email: "alice@example.com", name: "Alice")

# Or use partial application
admin_creator = CreateUser.with(role: "admin")
admin_creator.call(email: "bob@example.com", name: "Bob")
```

**[Get started →](getting-started)**

## Installation

```ruby
gem "typed_operation"
```

## Documentation

- **[Getting Started](getting-started)** - Installation, first operation, all core concepts
- **[API Reference](api)** - Complete method documentation
- **[Integrations](integrations)** - Rails, Dry::Monads, ActionPolicy
- **[Best Practices](best-practices)** - Testing, error handling, patterns
- **[Examples](examples)** - Comprehensive code examples
- **[Similar Gems](similar-gems)** - Comparison with alternatives

---
layout: home
title: TypedOperation
permalink: /
hero:
  name: TypedOperation
  text: A command pattern for Ruby with typed parameters
  tagline: Partial application, currying, and operation composition — with runtime type safety and first-class Rails, Dry::Monads, and Action Policy integration.
  actions:
    - theme: brand
      text: Get started
      link: /introduction/getting-started/
    - theme: alt
      text: View on GitHub
      link: https://github.com/stevegeek/typed_operation
features:
  - title: Type-safe parameters
    details: "Declare an operation's inputs with type constraints, validated at runtime via the Literal gem. A wrong-shape argument fails loudly the moment the operation is built."
  - title: Partial application & currying
    details: "Build specialized operations from general ones. Fix some parameters with .with, leave the rest open, or .curry to apply them one at a time."
  - title: Operation composition
    details: "Chain operations with .then and .or_else for railway-oriented flows, or compose them declaratively with the Pipeline DSL."
  - title: Result types
    details: "Built-in Success/Failure types with no dependencies, or drop in Dry::Monads for Result types and Do notation when you want them."
  - title: Rails integration
    details: "Generators scaffold your base class and operations. bin/rails g typed_operation:install wires everything up in one step."
  - title: Action Policy authorization
    details: "Declare authorization inline with action_type and authorized_via. Operations check the policy before perform runs."
---

## What is TypedOperation?

TypedOperation is an implementation of the Command pattern: each operation is a
small, callable object with explicitly typed parameters. Operations can be
partially applied, curried, pattern-matched, and composed into larger flows —
so business logic lives in consistent, testable, isolated units.

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

## Installation

Add this line to your application's Gemfile:

```ruby
gem "typed_operation"
```

For Rails, generate the base operation class:

```bash
bin/rails g typed_operation:install

# With optional integrations
bin/rails g typed_operation:install --dry_monads --action_policy
```

## Where to next

- [Getting started](/introduction/getting-started/) — installation and the core concepts.
- [Pipelines](/guides/pipelines/) — the Pipeline DSL and operation composition.
- [Integrations](/guides/integrations/) — Rails, Dry::Monads, and Action Policy.
- [API reference](/reference/api/) — the complete API.
- [Compared to other gems](/introduction/similar-gems/) — how TypedOperation differs.

# TypedOperation Architecture Overview

## Purpose

TypedOperation is a Ruby gem that implements the Command pattern with strong typing, partial application, and currying capabilities. It provides a structured way to encapsulate business logic into discrete, reusable, and testable operations.

## Core Architecture

### Inheritance Hierarchy

```
Literal::Struct / Literal::Data
    └── TypedOperation::Base / TypedOperation::ImmutableBase
```

### Key Components

1. **TypedOperation::Base** - Mutable operation base class built on `Literal::Struct`
2. **TypedOperation::ImmutableBase** - Immutable operation base class built on `Literal::Data`
3. **TypedOperation::PartiallyApplied** - Represents an operation with some parameters fixed
4. **TypedOperation::Prepared** - A fully parameterized operation ready for execution
5. **TypedOperation::Curried** - Enables functional-style currying of operations

## Design Principles

### 1. Type Safety
- All parameters are typed using the `literal` gem
- Type checking happens at instantiation time
- Support for complex types (unions, arrays, custom types)

### 2. Functional Programming Support
- Operations can be partially applied (`.with`)
- Full currying support (`.curry`)
- Operations are callable objects (`.call`)
- Immutable operation support via `ImmutableBase`

### 3. Flexibility
- Both positional and named parameters
- Optional parameters with defaults
- Parameter coercion via blocks
- Pattern matching support

### 4. Integration Ready
- Rails generator for `ApplicationOperation`
- Action Policy authorization module
- Dry::Monads integration examples
- Clean extension points

## Key Features

### Parameter Definition DSL
```ruby
class MyOperation < TypedOperation::Base
  positional_param :name, String
  named_param :age, Integer, optional: true
  param :email, String, &:downcase
end
```

### Partial Application
```ruby
# Fix some parameters, apply others later
op = MyOperation.with("John")
op.call(age: 30, email: "JOHN@EXAMPLE.COM")
```

### Currying
```ruby
# Transform into a series of single-argument functions
curried = MyOperation.curry
curried.("John").(30).("john@example.com")
```

### Pattern Matching
```ruby
case MyOperation.new("John", age: 30)
in MyOperation[name, age]
  puts "Name: #{name}, Age: #{age}"
end
```

## Extension Points

1. **Custom Base Classes** - Create domain-specific operation base classes
2. **Authorization** - Via `ActionPolicyAuth` module
3. **Result Types** - Integrate with Dry::Monads or similar
4. **Lifecycle Hooks** - `prepare`, `before_execute_operation`, `after_execute_operation`

## Thread Safety

- `TypedOperation::Base` instances are not frozen, but have no writer methods
- `TypedOperation::ImmutableBase` instances are frozen on initialization
- All partial application creates new instances
- No shared mutable state between operations

## Performance Considerations

- Type checking occurs at instantiation, not at definition
- Partial application creates intermediate objects
- Currying creates nested function objects
- Pattern matching is optimized via `deconstruct` methods
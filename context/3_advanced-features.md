# TypedOperation Advanced Features

## Partial Application

Partial application allows you to fix some parameters of an operation and create a new callable with the remaining parameters.

### Using `.with` (alias `[]`)

```ruby
class ProcessOrder < TypedOperation::Base
  positional_param :order_id, Integer
  named_param :user, User
  named_param :notify, _Boolean, default: true
  
  def perform
    # Process logic
  end
end

# Fix positional parameters
with_order = ProcessOrder.with(123)
# Returns: TypedOperation::PartiallyApplied

# Fix named parameters
with_user = ProcessOrder.with(user: current_user)
# Returns: TypedOperation::PartiallyApplied

# Fix multiple parameters
prepared = ProcessOrder.with(123, user: current_user)
# Returns: TypedOperation::Prepared (all required params satisfied)

# Call with remaining parameters
with_order.call(user: current_user, notify: false)

# Chain .with calls
ProcessOrder.with(123).with(user: current_user).call
```

### PartiallyApplied vs Prepared

- **PartiallyApplied**: Some required parameters are still missing
- **Prepared**: All required parameters are provided, ready to call

```ruby
partial = ProcessOrder.with(123)
partial.prepared?  # => false
partial.call       # => MissingParameterError

prepared = ProcessOrder.with(123, user: current_user)
prepared.prepared? # => true
prepared.call      # => Executes operation
```

### Important: Type Checking Timing

Type validation happens at instantiation, not during partial application:

```ruby
# This does NOT raise an error immediately
invalid = ProcessOrder.with("not_an_integer")

# Error occurs here when trying to instantiate
invalid.call(user: current_user)
# => Literal::TypeError: Expected Integer, got String
```

## Currying

Currying transforms a multi-parameter operation into a chain of single-parameter functions.

### Basic Currying

```ruby
class Calculate < TypedOperation::Base
  positional_param :a, Integer
  positional_param :b, Integer
  named_param :operation, Symbol
  
  def perform
    case operation
    when :add then a + b
    when :multiply then a * b
    end
  end
end

# Create curried version
curried = Calculate.curry

# Apply arguments one by one
add_5 = curried.(5)         # Fix first positional
add_5_to_10 = add_5.(10)    # Fix second positional
result = add_5_to_10.(:add) # Fix named param and execute
# => 15

# Or in one chain
Calculate.curry.(5).(10).(:add)
# => 15
```

### Currying with Partial Application

```ruby
# First partially apply optional parameters
multiply_op = Calculate.with(operation: :multiply)

# Then curry the remaining required parameters
curried = multiply_op.curry
curried.(3).(4)
# => 12
```

### Currying Order

1. Required positional parameters (in order)
2. Required named parameters (in definition order)

```ruby
class Example < TypedOperation::Base
  positional_param :a, String
  positional_param :b, String, optional: true
  named_param :x, Integer
  named_param :y, Integer
  named_param :z, Integer, optional: true
  
  def perform = "#{a}-#{b}-#{x}-#{y}-#{z}"
end

curried = Example.curry
curried.("A").("X").(1).(2)  # a, then x, then y
# => "A--1-2-"
```

## Pattern Matching

TypedOperation implements Ruby's pattern matching interface via `deconstruct` and `deconstruct_keys`.

### Array Pattern Matching

```ruby
class CreateUser < TypedOperation::Base
  positional_param :name, String
  positional_param :age, Integer
  named_param :email, String
  
  def perform = "Created #{name}"
end

user_op = CreateUser.new("Alice", 30, email: "alice@example.com")

case user_op
in CreateUser["Alice", age] if age >= 18
  puts "Adult user Alice, age #{age}"
in CreateUser[name, _]
  puts "User #{name}"
end
```

### Hash Pattern Matching

```ruby
case user_op
in CreateUser[name:, age: 20..40, email:]
  puts "User #{name} is in their 20s or 30s"
in CreateUser[name: /^A/, **rest]
  puts "User whose name starts with A: #{rest}"
end
```

### Pattern Matching with PartiallyApplied

```ruby
partial = CreateUser.with("Bob", 25)

case partial
in TypedOperation::PartiallyApplied[positional_args: ["Bob", age]]
  puts "Partial with Bob, age #{age}"
end
```

## Method Conversion

### `.to_proc` (Class Method)

Convert operation class to a proc:

```ruby
class Double < TypedOperation::Base
  positional_param :value, Integer
  def perform = value * 2
end

[1, 2, 3].map(&Double)
# => [2, 4, 6]

# With partial application
add_10 = ->(x) { x + 10 }
[1, 2, 3].map(&Double.with.method(:call))
```

### `#to_proc` (Instance Method)

Convert operation instance to a proc:

```ruby
doubler = Double.new(5)
proc = doubler.to_proc
proc.call  # => 10
```

## Advanced Introspection

### Checking Operation State

```ruby
class MyOp < TypedOperation::Base
  positional_param :a, String
  named_param :b, Integer
  def perform = "#{a}-#{b}"
end

# Check if partially applied
partial = MyOp.with("test")
partial.is_a?(TypedOperation::PartiallyApplied)  # => true

# Check if prepared
prepared = MyOp.with("test", b: 1)
prepared.is_a?(TypedOperation::Prepared)  # => true
prepared.prepared?  # => true

# Access operation class from partial
partial.operation  # => MissingParameterError
prepared.operation # => #<MyOp a="test" b=1>
```

### Accessing Applied Arguments

```ruby
partial = MyOp.with("hello").with(b: 42)

# In PartiallyApplied/Prepared
partial.positional_args  # => ["hello"]
partial.keyword_args     # => {b: 42}
```

## Functional Composition Patterns

### Pipeline Pattern

```ruby
class Parse < TypedOperation::Base
  positional_param :input, String
  def perform = JSON.parse(input)
end

class Transform < TypedOperation::Base
  positional_param :data, Hash
  def perform = data.transform_keys(&:to_sym)
end

class Validate < TypedOperation::Base
  positional_param :data, Hash
  def perform
    raise "Invalid" unless data[:id]
    data
  end
end

# Compose operations
pipeline = ->(input) {
  input
    .then(&Parse)
    .then(&Transform)
    .then(&Validate)
}

result = pipeline.call('{"id": 1, "name": "test"}')
# => {:id=>1, :name=>"test"}
```

### Higher-Order Operations

```ruby
class Map < TypedOperation::Base
  positional_param :collection, _Array(:any)
  named_param :operation, TypedOperation::Base
  
  def perform
    collection.map { |item| operation.with(item).call }
  end
end

# Usage
doubles = Map.new([1, 2, 3], operation: Double)
doubles.call  # => [2, 4, 6]
```
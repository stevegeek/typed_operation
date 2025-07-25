# TypedOperation Core Concepts

## Parameter System

### Parameter Definition Methods

TypedOperation provides three ways to define parameters:

1. **`param`** - Base method, creates named parameters by default
2. **`positional_param`** - Explicitly creates positional parameters
3. **`named_param`** - Explicitly creates named parameters (same as `param`)

### Parameter Options

```ruby
param :name, Type, <options>
```

Options:
- `positional: true/false` - Makes parameter positional
- `optional: true/false` - Makes parameter optional
- `default: value/proc` - Sets default value
- `reader: :public/:private` - Controls accessor visibility
- Block for coercion

### Type System (via Literal gem)

#### Basic Types
```ruby
param :name, String
param :age, Integer
param :active, _Boolean
```

#### Complex Types
```ruby
include Literal::Types

param :tags, _Array(String)
param :status, _Union(String, Symbol)
param :user, _Nilable(User)  # Same as optional(User)
param :data, _Hash(String, Integer)
```

#### Optional Types
```ruby
# Three ways to make optional:
param :name, String, optional: true
param :name, optional(String)
param :name, _Nilable(String)  # Using Literal::Types
```

### Parameter Coercion

Coercion blocks transform input values:

```ruby
param :email, String, &:downcase
param :age, Integer, &:to_i
param :tags, _Array(String) do |value|
  value.is_a?(String) ? value.split(',') : Array(value)
end
```

**Important**: For nilable types, coercion blocks don't run on nil values.

### Parameter Order Rules

1. Required positional parameters must come before optional ones
2. Named parameters can be defined in any order
3. Mixing positional and named parameters is allowed

```ruby
class ValidOrder < TypedOperation::Base
  positional_param :required1, String
  positional_param :required2, String
  positional_param :optional1, String, optional: true
  named_param :name, String
  named_param :age, Integer, optional: true
end
```

## Operation Lifecycle

### 1. Instantiation Phase

```ruby
# Parameters are validated and coerced
operation = MyOperation.new("value", key: "value")
```

- Type checking occurs here
- Coercion blocks are applied
- `after_initialize` is called (Literal hook)
- `prepare` method is called if defined

### 2. Execution Phase

```ruby
result = operation.call
```

Execution flow:
1. `call` → `execute_operation`
2. `before_execute_operation` (hook)
3. `perform` (main logic - must be implemented)
4. `after_execute_operation(result)` (hook)

### Lifecycle Hooks

```ruby
class MyOperation < TypedOperation::Base
  param :data, String

  # Called after parameters are set
  def prepare
    validate_data!
  end

  # Called before perform
  def before_execute_operation
    setup_resources
    super  # Important for subclass chains
  end

  # Main operation logic
  def perform
    process_data
  end

  # Called after perform
  def after_execute_operation(result)
    cleanup_resources
    super(result)  # Pass result through
  end
end
```

## Base Class Differences

### TypedOperation::Base
- Built on `Literal::Struct`
- Mutable internals (but no setters)
- Compatible with all features
- Use for most operations

### TypedOperation::ImmutableBase
- Built on `Literal::Data`
- Frozen after initialization
- **Cannot** use `ActionPolicyAuth`
- Use when immutability is critical

## Parameter Introspection

Operations provide class methods for parameter inspection:

```ruby
MyOperation.positional_parameters          # [:name, :age]
MyOperation.keyword_parameters             # [:email, :active]
MyOperation.required_positional_parameters # [:name]
MyOperation.required_keyword_parameters    # [:email]
MyOperation.optional_positional_parameters # [:age]
MyOperation.optional_keyword_parameters    # [:active]
```

## Error Handling

TypedOperation defines three main error types:

1. **`Literal::TypeError`** - Parameter type mismatch
2. **`TypedOperation::MissingParameterError`** - Required parameter missing
3. **`TypedOperation::InvalidOperationError`** - Operation misconfiguration

```ruby
# Type error
MyOperation.new(123)  # Expected String, got Integer

# Missing parameter
MyOperation.with("name").call  # Missing required :email

# Invalid operation
class BadOp < TypedOperation::Base
  # No perform method defined
end
BadOp.new.call  # InvalidOperationError
```

## Internal Implementation Details

### PropertyBuilder

The `PropertyBuilder` class handles parameter definition:
1. Wraps type in `NilableType` if optional
2. Adds nil to union type if default is nil
3. Validates positional parameter order
4. Sets up coercion wrappers for nilable types

### Parameter Storage

Parameters are stored as Literal properties:
- Positional: `prop :name, Type, :positional`
- Named: `prop :name, Type, :keyword`
- No writers are created (writer: false)

### Execution Context

- Operations maintain no internal state beyond parameters
- Each execution is independent
- Thread-safe by design (no shared mutable state)
---
title: API Reference
nav_order: 1
---

# API Reference

Complete API reference for TypedOperation.

## Base Classes

### TypedOperation::Base

Mutable operation class built on `Literal::Struct`.

```ruby
class MyOperation < TypedOperation::Base
  param :name, String
  def perform; name.upcase; end
end
```

### TypedOperation::ImmutableBase

Immutable operation class built on `Literal::Data`. The instance is frozen after initialization.

```ruby
class MyOperation < TypedOperation::ImmutableBase
  param :name, String
  def perform; name.upcase; end
end
```

**Note:** `ImmutableBase` does not support `ActionPolicyAuth`.

---

## Configuration

### TypedOperation.configure

Configure global settings for TypedOperation.

```ruby
TypedOperation.configure do |config|
  config.result_adapter = :dry_monads
end
```

### TypedOperation.configuration

Returns the current `Configuration` instance.

```ruby
TypedOperation.configuration.result_adapter
```

### TypedOperation.reset_configuration!

Reset configuration to defaults. Primarily for testing.

```ruby
TypedOperation.reset_configuration!
```

### Configuration#result_adapter

Get or set the result adapter used for `Success()` and `Failure()` helpers.

**Options:**
- `:built_in` (default) - Uses `TypedOperation::Result::Success` and `TypedOperation::Result::Failure`
- `:dry_monads` - Uses `Dry::Monads::Success` and `Dry::Monads::Failure` (requires dry-monads gem)

```ruby
# Set via configure block
TypedOperation.configure do |config|
  config.result_adapter = :dry_monads
end

# Or set directly
TypedOperation.configuration.result_adapter = :built_in
```

**When to use each adapter:**

| Adapter | Use When |
|---------|----------|
| `:built_in` | Default. No external dependencies. Sufficient for most cases. |
| `:dry_monads` | Already using dry-monads in your project. Want ecosystem integration. |

---

## Parameter DSL

### param(name, type, **options, &converter)

Define a keyword parameter.

```ruby
param :email, String                        # Required
param :role, String, default: "user"        # With default
param :bio, optional(String)                # Optional (nilable) via helper
param :phone, String, optional: true        # Optional (nilable) via option — equivalent
param :count, Integer, &:to_i               # With coercion
```

**Options:**

| Option | Type | Description |
|--------|------|-------------|
| `positional` | Boolean | If `true`, parameter is positional (default: `false`) |
| `default` | Any/Proc | Default value or proc for lazy evaluation |
| `optional` | Boolean | If `true`, wraps type in `_Nilable`. Equivalent to wrapping the type with `optional(...)` — use whichever reads better |
| `reader` | Symbol | Visibility: `:public`, `:private`, `:protected` |

**Coercion block:** Called with the input value before type checking.

### positional_param(name, type, **options, &converter)

Define a positional parameter. Equivalent to `param` with `positional: true`.

```ruby
positional_param :filename, String
positional_param :format, String, default: "json"
```

### named_param(name, type, **options, &converter)

Alias for `param` with `positional: false`. Explicit keyword parameter.

### optional(type)

Wraps a type to accept `nil`. Returns `Literal::Types::NilableType`.

```ruby
param :nickname, optional(String)       # Equivalent to _Nilable(String)
param :nickname, String, optional: true # Equivalent form using the option
```

---

## Type System (Literal::Types)

Include `Literal::Types` for type helpers:

```ruby
class MyOp < TypedOperation::Base
  include Literal::Types

  param :active, _Boolean
  param :tags, _Array(String)
  param :meta, _Hash(String, Integer)
  param :id, _Union(Integer, String)
  param :user, _Nilable(User)
  param :status, _Enum("pending", "active")
end
```

| Type | Description |
|------|-------------|
| `_Boolean` | `true` or `false` |
| `_Array(T)` | Array containing type T |
| `_Hash(K, V)` | Hash with key type K, value type V |
| `_Union(A, B, ...)` | Any of the specified types |
| `_Nilable(T)` | Type T or `nil` |
| `_Enum(*values)` | One of the specified values |

See [literal gem documentation](https://literal.fun) for complete type system.

---

## Execution Methods

### Class Methods

#### .call(*args, **kwargs)

Instantiate and execute the operation. Returns the result of `perform`.

```ruby
result = MyOperation.call(name: "Alice")
```

#### .new(*args, **kwargs)

Create an operation instance without executing.

```ruby
op = MyOperation.new(name: "Alice")
op.call  # Execute later
```

#### .to_proc

Convert operation to a proc that calls `.call`.

```ruby
proc = MyOperation.to_proc
proc.call(name: "Alice")
```

### Instance Methods

#### #call

Execute the operation. Calls `#execute_operation` internally.

```ruby
op = MyOperation.new(name: "Alice")
result = op.call
```

#### #execute_operation

Internal execution method. Calls hooks and `perform`:

1. `before_execute_operation`
2. `perform`
3. `after_execute_operation(result)`

#### #to_proc

Convert instance to a proc that calls `#call`.

---

## Lifecycle Hooks

### #prepare

Called after initialization, before execution. Use for validation or setup.

```ruby
def prepare
  raise ArgumentError, "Invalid" unless valid?
end
```

If `prepare` raises an exception, the operation does not execute and the exception propagates to the caller.

### #before_execute_operation

Called immediately before `perform`. Always call `super`.

```ruby
def before_execute_operation
  @start_time = Time.current
  super
end
```

If this hook raises an exception, `perform` is not called and the exception propagates to the caller.

### #after_execute_operation(result)

Called after `perform` with its return value. Return value becomes final result. Always call `super`.

```ruby
def after_execute_operation(result)
  log_result(result)
  super  # Returns result
end
```

If this hook raises an exception, it propagates to the caller. The `perform` method has already completed.

### #perform

**Required.** Main business logic. Return value is the operation result.

```ruby
def perform
  User.create!(email: email)
end
```

Raises `InvalidOperationError` if not implemented.

**Note on error handling:** Exceptions from callbacks (`prepare`, `before_execute_operation`, `after_execute_operation`) propagate to the caller. Use `Dry::Monads` Result types for explicit error handling instead of exceptions.

---

## Partial Application

### Class Methods

#### .with(*args, **kwargs)

Create a partially applied operation. Returns `PartiallyApplied` or `Prepared`.

```ruby
partial = MyOp.with(name: "Alice")  # PartiallyApplied or Prepared
```

#### .[](*args, **kwargs)

Alias for `.with`.

```ruby
partial = MyOp[name: "Alice"]
```

#### .curry

Create a curried operation. Returns `Curried`.

```ruby
curried = MyOp.curry
curried.(arg1).(arg2).(arg3)
```

### TypedOperation::PartiallyApplied

Represents an operation missing some required parameters.

#### #with(*args, **kwargs) / #[]

Add more parameters. Returns `PartiallyApplied` or `Prepared`.

```ruby
partial = partial.with(age: 30)
```

#### #call(*args, **kwargs)

Add parameters and execute if prepared. Raises `MissingParameterError` if still missing params.

```ruby
partial.call(remaining: "value")
```

#### #curry

Convert to `Curried` for single-argument application.

#### #prepared?

Returns `false`.

#### #operation

Raises `MissingParameterError`.

#### #to_proc

Returns proc that calls `#call`.

#### #positional_args / #keyword_args

Access stored arguments.

#### #deconstruct / #deconstruct_keys(keys)

Pattern matching support.

### TypedOperation::Prepared

Extends `PartiallyApplied`. All required parameters provided.

#### #operation

Returns the operation instance without executing.

```ruby
op = prepared.operation
op.name  # Access parameters
```

#### #prepared?

Returns `true`.

#### #call

Execute the operation.

#### #explain

Execute with tracing. Requires `Explainable`.

### TypedOperation::Curried

Wraps an operation for single-argument currying.

#### #call(arg)

Apply next argument. Returns `Curried` or executes if all required params provided.

```ruby
curried.(10).(20).(30)  # => result
```

#### #to_proc

Returns proc that calls `#call`.

---

## Introspection (Class Methods)

#### .positional_parameters

Returns array of positional parameter names.

```ruby
MyOp.positional_parameters  # => [:arg1, :arg2]
```

#### .keyword_parameters

Returns array of keyword parameter names.

```ruby
MyOp.keyword_parameters  # => [:name, :email, :role]
```

#### .required_positional_parameters

Returns array of required positional parameter names.

#### .required_keyword_parameters

Returns array of required keyword parameter names.

#### .optional_positional_parameters

Returns array of optional positional parameter names.

#### .optional_keyword_parameters

Returns array of optional keyword parameter names.

---

## Pattern Matching

### #deconstruct

Array-style pattern matching. Returns positional parameter values.

```ruby
case operation
in MyOp[value1, value2]
  # Match positional values
end
```

### #deconstruct_keys(keys)

Hash-style pattern matching. Returns parameter hash.

```ruby
case operation
in MyOp[name:, age:]
  puts "#{name}, #{age}"
in MyOp[name:, role: "admin"]
  puts "Admin: #{name}"
end
```

---

## Debugging (TypedOperation::Explainable)

Include in your base operation to enable tracing:

```ruby
class ApplicationOperation < TypedOperation::Base
  include TypedOperation::Explainable
end
```

### .explain(*args, **kwargs)

Execute with tracing. Prints execution tree to stdout.

```ruby
MyOp.explain(param: value)
# Output:
# MyOp [1.23ms] ✓
# ├── NestedOp [0.45ms] ✓
# └── AnotherOp [0.67ms] ✓
```

To customize output or disable color, use `Instrumentation.with_output`.

### TypedOperation::Instrumentation.with_output(io, color: nil, &block)

Control output and color for tracing within a block.

```ruby
# Write to file
File.open("trace.log", "w") do |f|
  TypedOperation::Instrumentation.with_output(f, color: false) do
    MyOp.explain(param: value)
  end
end

# Disable color for stdout
TypedOperation::Instrumentation.with_output($stdout, color: false) do
  MyOp.explain(param: value)
end
```

**Parameters:**
- `io` - IO object (e.g., file, $stdout, $stderr)
- `color:` - `true`, `false`, or `nil` (auto-detect)

### TypedOperation::Instrumentation.explaining(&block)

Trace multiple operations in a block:

```ruby
TypedOperation::Instrumentation.explaining do
  Op1.call(...)
  Op2.call(...)
end
```

### TypedOperation::Instrumentation.tracing?

Returns `true` if inside a trace context.

### TypedOperation::Instrumentation.current_trace

Returns current `Trace` object or `nil`.

### TypedOperation::Instrumentation.clear_trace!

Clears all trace context from the current thread.

### TypedOperation::Instrumentation::Trace

The `Trace` object returned by `current_trace` has these properties:

| Property | Type | Description |
|----------|------|-------------|
| `operation_class` | Class | The operation class being traced |
| `operation_name` | String | Class name as string |
| `params` | Hash | Parameters passed to the operation |
| `start_time` | Float | Monotonic clock time when execution started |
| `end_time` | Float | Monotonic clock time when execution finished |
| `duration_ms` | Float | Execution time in milliseconds |
| `result` | Any | Return value of the operation |
| `exception` | Exception | Exception raised, if any |
| `success?` | Boolean | `true` if no exception was raised |
| `children` | Array | Nested `Trace` objects for child operations |

```ruby
# Access trace data programmatically
TypedOperation::Instrumentation.explaining do
  result = MyOperation.call(param: value)

  trace = TypedOperation::Instrumentation.current_trace
  trace.children.each do |child|
    puts "#{child.operation_name}: #{child.duration_ms}ms"
  end
end
```

---

## Operation Composition

These methods are available on operations, `PartiallyApplied`, and `Prepared`.

### Railway-Oriented Programming

Composition chains implement railway-oriented programming with two tracks:

- **Success Track**: Operations execute sequentially while each returns `Success`
- **Failure Track**: First `Failure` short-circuits the chain, skipping remaining operations

```ruby
ValidateEmail
  .then(CreateUser)      # Skipped if ValidateEmail fails
  .then(SendWelcome)     # Skipped if CreateUser fails
  .or_else(HandleError)  # Only executes on Failure
```

### Context Accumulation

Chains accumulate context across operations. Each operation's return value is merged into the context hash, which flows to subsequent operations.

```ruby
class Op1 < TypedOperation::Base
  param :input, String
  def perform
    Success(result1: input.upcase)
  end
end

class Op2 < TypedOperation::Base
  param :input, String
  param :result1, String
  def perform
    Success(result2: "#{input} + #{result1}")
  end
end

chain = Op1.then(Op2)
result = chain.call(input: "hello")
result.value!
# => {input: "hello", result1: "HELLO", result2: "hello + HELLO"}
```

### #then(operation, **extra_kwargs, &block)

Smart sequential composition. Auto-detects whether to spread kwargs or pass as single value based on the next operation's signature.

**How it works:**
- Inspects next operation's parameters
- If operation has keyword params: extracts needed values from context as `**kwargs`
- If operation has positional params: passes entire context hash as single argument
- Merges result back into context

**Constraint:** Raises `ArgumentError` if operation has both positional AND keyword params. Use `.transform` to adapt.

```ruby
# With keyword param operation
ValidateUser
  .with(email: email)
  .then(CreateUser)  # Receives extracted kwargs
  .call

# With block (receives context hash)
ValidateUser
  .then { |ctx| SendWelcome.with(user_id: ctx[:user_id]) }
  .call

# Pass extra kwargs to override context values
Op1.then(Op2, role: "admin")  # Merges {role: "admin"} into context
```

**Block receives context hash**, not individual values:

```ruby
ValidateUser
  .then { |ctx| SendEmail.with(email: ctx[:user][:email]) }
  .call
```

### #then_spreads(operation, &block)

Always spreads the context as `**kwargs` to the next operation. Use when you want explicit kwargs spreading.

```ruby
op.then_spreads(NextOp)  # NextOp.call(**context)

# With block (receives context hash)
op.then_spreads { |ctx| ctx.merge(processed: true) }
```

Context must be a Hash or respond to `#to_h`. Raises `ArgumentError` otherwise.

### #then_passes(operation, &block)

Always passes the context as a single positional argument to the next operation. Use for operations expecting a single Hash or Context object.

```ruby
op.then_passes(NextOp)  # NextOp.call(context)

# With block (receives context hash)
op.then_passes { |ctx| {result: ctx[:value] * 2} }
```

### #transform(&block)

Maps over the success value, replacing the context entirely (does not merge). Block receives context hash. Block return is auto-wrapped in `Success`.

Use for changing the shape of the context or extracting specific values.

```ruby
# Replace context with transformed value
op.transform { |ctx| {new_key: ctx[:old_key].upcase} }

# Extract single value
op.transform { |ctx| ctx[:user][:email] }

# Not called on Failure (short-circuits)
failing_op.transform { |ctx| raise "never called" }
```

**Difference from `.then`:** `.transform` replaces context, `.then` merges into context.

### #or_else(fallback, &block)

Provides a fallback when the operation fails. Only called if left side returns `Failure`. Passes through `Success` unchanged.

**With operation class:** Receives original call arguments (allows retry with different implementation).

```ruby
ChargeCard
  .with(amount: 100)
  .or_else(ChargeBackupPaymentGateway)  # Receives same {amount: 100}
  .call
```

**With block:** Receives the failure value.

```ruby
ValidateUser
  .or_else { |failure|
    Rails.logger.error(failure)
    Failure([:handled, failure])
  }
  .call
```

Not called on success:

```ruby
successful_op.or_else { raise "never called" }  # Fallback skipped
```

---

## TypedOperation::Context

Specialized Hash wrapper for passing data through pipelines and chains. Provides dot notation access and common Hash-like methods.

### Creating and Accessing

```ruby
# Create
ctx = TypedOperation::Context.new(user: "alice", role: "admin")

# Read
ctx[:user]       # Hash-style
ctx.user         # Dot notation
ctx.fetch(:user, "default")  # With default

# Write
ctx[:role] = "admin"
ctx.role = "admin"

# Check keys
ctx.key?(:user)  # => true
ctx.user?        # => true (predicate method)
```

### Common Operations

```ruby
# Conversion
ctx.to_h         # Returns Hash (dup)

# Merging
ctx.merge(email: "user@example.com")  # Returns new Context

# Iteration
ctx.keys         # => [:user, :role]
ctx.values       # => ["alice", "admin"]
ctx.each { |k, v| puts "#{k}: #{v}" }

# Filtering
ctx.select { |k, v| v.is_a?(String) }  # Returns new Context
ctx.reject { |k, v| v.nil? }

# Transformation
ctx.transform_values { |v| v.to_s }
ctx.slice(:user, :role)
ctx.except(:internal_field)

# Inspection
ctx.empty?       # => false
ctx.size         # => 2
```

### Using Context in Operations

```ruby
class MyOperation < TypedOperation::Base
  positional_param :ctx, TypedOperation::Context

  def perform
    user = ctx.user      # Dot notation
    role = ctx[:role]    # Hash notation

    ctx.processed = true
    Success(ctx)
  end
end
```

### Custom Context Classes

Implement this interface to use your own context class:

```ruby
class MyContext
  def [](key)        # Read value
  def []=(key, val)  # Write value (optional if immutable)
  def key?(key)      # Check key existence
  def to_h           # Convert to Hash
  def merge(other)   # Combine, returns new context
end
```

---

## Result Types

TypedOperation provides built-in `Success` and `Failure` types for explicit error handling. Operations can return these types directly, or use the configured result adapter via the `Success()` and `Failure()` helper methods.

### TypedOperation::Result::Success

Represents a successful result. Immutable value object.

```ruby
success = TypedOperation::Result::Success.new(42)
success.success?  # => true
success.failure?  # => false
success.value!    # => 42
success.value     # => 42
success.failure   # => nil
```

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `success?` | `true` | Always returns `true` |
| `failure?` | `false` | Always returns `false` |
| `value!` | Any | Returns the wrapped value |
| `value` | Any | Alias for `value!` |
| `failure` | `nil` | Always returns `nil` for Success |
| `deconstruct` | Array | Pattern matching support (array destructuring) |
| `deconstruct_keys(keys)` | Hash | Pattern matching support (hash destructuring) |

### TypedOperation::Result::Failure

Represents a failed result. Immutable value object.

```ruby
failure = TypedOperation::Result::Failure.new(:not_found)
failure.success?  # => false
failure.failure?  # => true
failure.error     # => :not_found
failure.failure   # => :not_found
failure.value!    # Raises TypedOperation::UnwrapError
```

#### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `success?` | `false` | Always returns `false` |
| `failure?` | `true` | Always returns `true` |
| `value!` | N/A | Raises `UnwrapError` |
| `error` | Any | Returns the wrapped error value |
| `failure` | Any | Alias for `error` |
| `deconstruct` | Array | Pattern matching support (array destructuring) |
| `deconstruct_keys(keys)` | Hash | Pattern matching support (hash destructuring) |

### TypedOperation::Result::Mixin

Include this module to get `Success()` and `Failure()` helper methods that use the configured result adapter.

```ruby
class MyOperation < TypedOperation::Base
  include TypedOperation::Result::Mixin

  def perform
    return Failure(:invalid) unless valid?
    Success(compute_result)
  end
end
```

The helpers are private methods that delegate to the configured adapter:

```ruby
Success(value)  # Uses TypedOperation.configuration.result_adapter.success(value)
Failure(error)  # Uses TypedOperation.configuration.result_adapter.failure(error)
```

### Pattern Matching

Both Success and Failure support Ruby 3+ pattern matching:

```ruby
case result
in Success(value)
  puts "Got: #{value}"
in Failure(error)
  puts "Error: #{error}"
end

# With array destructuring
case result
in Failure[:validation_error, details]
  puts "Validation failed: #{details}"
end

# With hash destructuring (delegates to wrapped value)
case success_with_hash
in Success[name:, email:]
  puts "User: #{name} (#{email})"
end
```

---

## ActionPolicy Authorization

Include `TypedOperation::ActionPolicyAuth` for authorization. Only works with `Base`, not `ImmutableBase`.

### .authorized_via(*params, with:, to:, record:, &block)

Configure authorization. Accepts one or more parameter names that provide authorization context (typically a user or account).

```ruby
# With policy class
authorized_via :current_user, with: PostPolicy, to: :create?

# With block (creates inline policy)
authorized_via :current_user do
  user.admin?
end

# With record to authorize
authorized_via :current_user, with: PostPolicy, to: :destroy?, record: :post

# Multiple context parameters
authorized_via :current_owner, :new_owner, with: TransferPolicy, to: :can_transfer?

# record parameter can refer to any parameter or method
authorized_via :current_user, with: PostPolicy, to: :update?, record: :post_to_edit
```

**Parameters:**

| Option | Description |
|--------|-------------|
| `*params` | One or more parameter names providing authorization context. Multiple params can be passed for policies that need multiple actors. |
| `with:` | Policy class to use. Required unless `&block` provided. |
| `to:` | Policy method to call (e.g., `:create?`). Defaults to `action_type` method if not specified. |
| `record:` | Optional. Parameter or method name providing the record to authorize. If omitted, ActionPolicy attempts to infer it from context. |
| `&block` | Inline policy definition (alternative to `with:`). Creates anonymous policy class. |

Authorization is inherited by subclasses.

### .action_type(type = nil)

Set/get action type. Used as default policy method.

```ruby
action_type :create
# Calls :create? on policy
```

### .verify_authorized!

Require authorization in all subclasses. Raises `MissingAuthentication` if not configured.

### .checks_authorization?

Returns `true` if authorization is configured.

### #on_authorization_failure(error)

Hook called when authorization fails. Define as instance method to add side effects like logging. The authorization error (`ActionPolicy::Unauthorized`) is always re-raised after this hook executes.

```ruby
def on_authorization_failure(error)
  Rails.logger.warn "Unauthorized: #{current_user&.id} - #{error.message}"
  Rails.logger.warn "Policy: #{error.policy}, Rule: #{error.rule}"
end
```

The `error` parameter is an `ActionPolicy::Unauthorized` exception with these properties:
- `error.message` - Human-readable error message
- `error.policy` - The policy class that failed
- `error.rule` - The policy method that returned false
- `error.result` - ActionPolicy result object with detailed failure reasons

---

## Exceptions

### TypedOperation::MissingParameterError

Raised when calling a `PartiallyApplied` operation or accessing `.operation` without all required parameters.

### TypedOperation::InvalidOperationError

Raised when:
- `#perform` is not implemented
- Invalid operation configuration
- `explain` called without `Explainable`

### TypedOperation::MissingAuthentication

Raised when `verify_authorized!` is set but authorization is not configured.

### TypedOperation::UnwrapError

Raised when calling `value!` on a `Failure` result.

```ruby
failure = TypedOperation::Result::Failure.new(:not_found)
failure.value!  # Raises UnwrapError: "Cannot unwrap Failure: :not_found"
```

### Literal::TypeError

Raised when a parameter value doesn't match its type constraint.

### ActionPolicy::Unauthorized

Raised when authorization check fails (from ActionPolicy gem).

---

## Rails Integration

### Generators

#### typed_operation:install

Creates `ApplicationOperation` base class.

```bash
bin/rails g typed_operation:install
bin/rails g typed_operation:install --dry_monads
bin/rails g typed_operation:install --action_policy
```

#### typed_operation

Creates an operation and test file.

```bash
bin/rails g typed_operation CreateUser email:string name:string
```

Creates:
- `app/operations/create_user_operation.rb`
- `test/operations/create_user_operation_test.rb`

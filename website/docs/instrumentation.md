---
layout: default
title: Instrumentation
nav_order: 6
permalink: /instrumentation
---

# Instrumentation
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

Runtime tracing and debugging for operations and chains.

## Basic Usage

### Tracing a Single Call

```ruby
result = MyOperation.explain(param: value)
```

Prints an execution tree to stdout and returns the result.

### Tracing a Block

```ruby
TypedOperation::Instrumentation.explaining do
  MyOperation.call(params)
  AnotherOperation.call(other_params)
end
```

### Custom Output

Control where trace output is written and whether to use colors:

```ruby
TypedOperation::Instrumentation.with_output($stderr, color: false) do
  MyOperation.explain(param: value)
end
```

**Method signature:**
- `Instrumentation.with_output(io, color: nil, &block)`
  - `io` - Any IO object (e.g., `$stdout`, `$stderr`, `StringIO.new`)
  - `color` - Boolean to enable/disable ANSI colors (defaults to auto-detect based on TTY)

## Pass Modes

When tracing chained operations, the trace output shows how values are passed between operations:

- `(**ctx)` - Context splatted as keyword arguments
  - Appears with `.then` when the next operation accepts keyword parameters
  - Smart chaining automatically extracts matching parameters from context
- `(ctx)` - Single value passed as positional argument
  - Appears with `.then` when the next operation accepts a single positional parameter
  - Also used with `.then_passes` to explicitly pass the full context
- `(transform)` - Value transformed by a block
  - Appears with `.transform` method
- `(fallback)` - Fallback operation executed after failure
  - Appears with `.or_else` method

### Chain Tracing Examples

#### Smart Chaining with Extracted Parameters

When chaining operations that accept keyword arguments, the tracer shows which parameters were extracted from the context:

```ruby
class CreateUser < TypedOperation::Base
  include TypedOperation::Explainable
  param :email, String
  param :name, String

  def perform
    {id: 1, email: email, name: name}
  end
end

class SendWelcome < TypedOperation::Base
  include TypedOperation::Explainable
  param :email, String
  param :name, String

  def perform
    "Welcome email sent to #{email}"
  end
end

chain = CreateUser.then(SendWelcome)
chain.explain(email: "user@example.com", name: "Alice")

# Output:
# CreateUser [2.1ms] ✓
#   →
# SendWelcome [1.3ms] ✓ (**ctx) ← [email, name]
# => "Welcome email sent to user@example.com"
```

**Understanding the output:**
- `(**ctx)` - Indicates keyword argument splatting was used
- `← [email, name]` - Shows which parameters were extracted from the previous operation's result
  - This helps you see which fields from the context are being passed to each operation
  - Only parameters that match the operation's defined parameters are extracted

#### Fallback Chains

Fallback operations are shown with a special arrow:

```ruby
class ApiCall < TypedOperation::Base
  include TypedOperation::Explainable
  param :should_fail, _Boolean

  def perform
    raise "API error" if should_fail
    "success"
  end
end

class FallbackHandler < TypedOperation::Base
  include TypedOperation::Explainable

  def perform
    "fallback response"
  end
end

chain = ApiCall.or_else(FallbackHandler)
chain.explain(should_fail: true)

# Output:
# ApiCall [0.5ms] ✗ (RuntimeError: API error)
#   ⤷
# ⤷ FallbackHandler [0.2ms] ✓ (fallback)
# => "fallback response"
```

The `⤷` arrow indicates fallback execution, and `(fallback)` shows the pass mode.

## How It Works

Instrumentation uses thread-local storage to track execution without modifying call signatures. Two mechanisms work together:

1. **Trace Stack** - Maintains the call hierarchy as a stack of `Trace` objects
2. **Chain Context** - Captures metadata about how operations are invoked (pass mode, extracted parameters, fallback status)

When `.explain` is called, a root trace is pushed (enabling `tracing? = true`). As chains execute, they record context via `set_chain_context` before calling each operation. The operation's `Traceable` wrapper consumes this context via `take_chain_context`, then pushes/pops traces as execution progresses.

Thread-locals provide a side-channel for passing instrumentation data without polluting the `call` interface. Since `Thread.current[]` isolates data per-thread and chains execute synchronously, this approach is thread-safe. The `tracing?` guard ensures instrumentation is a no-op when not actively debugging.

---
layout: default
title: Integrations
nav_order: 5
permalink: /integrations
---

# Integrations
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

TypedOperation provides first-class integrations with Rails, Dry::Monads, and ActionPolicy.

## Rails

### Generators

#### Install Generator

Create an `ApplicationOperation` base class:

```bash
bin/rails g typed_operation:install
bin/rails g typed_operation:install --dry_monads
bin/rails g typed_operation:install --action_policy
bin/rails g typed_operation:install --dry_monads --action_policy
```

Creates `app/operations/application_operation.rb` with requested integrations.

#### Operation Generator

Create a new operation:

```bash
bin/rails g typed_operation CreateUser
bin/rails g typed_operation users/Create --path=app/operations
```

Creates:
- `app/operations/create_user_operation.rb`
- `test/operations/create_user_operation_test.rb`

### Directory Structure

```
app/operations/
├── application_operation.rb
├── users/
│   ├── create_operation.rb
│   └── update_operation.rb
└── orders/
    └── process_operation.rb
```

**Naming conventions:**
- Class: `CreateUserOperation` or `Users::CreateOperation`
- File: `create_user_operation.rb` or `users/create_operation.rb`

### ApplicationOperation Patterns

```ruby
class ApplicationOperation < TypedOperation::Base
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)

  param :current_user, optional(User)

  private

  def user_signed_in?
    current_user.present?
  end
end
```

### Usage in Rails

**Controllers:**
```ruby
def create
  case Users::CreateOperation.call(**user_params)
  in Success(user)
    redirect_to user, notice: "Created"
  in Failure[code, message]
    flash.now[:alert] = message
    render :new
  end
end
```

**Background jobs:**
```ruby
class ProcessOrderJob < ApplicationJob
  def perform(order_id)
    Orders::ProcessOperation.call(order_id: order_id)
  end
end
```

---

## Dry::Monads

[Dry::Monads](https://dry-rb.org/gems/dry-monads/) provides `Success`/`Failure` types for explicit error handling.

### Installation

```ruby
gem "dry-monads"
```

### Usage Options

**Option 1: Include directly per-operation** (simplest):

```ruby
class CreateUser < TypedOperation::Base
  include Dry::Monads[:result]

  def perform
    Success(user)  # Dry::Monads::Success
  end
end
```

**Option 2: Configure globally** (use with `Result::Mixin`):

```ruby
# config/initializers/typed_operation.rb
TypedOperation.configure do |config|
  config.result_adapter = :dry_monads
end

# In operations
class CreateUser < TypedOperation::Base
  include TypedOperation::Result::Mixin  # Now returns Dry::Monads types

  def perform
    Success(user)  # Dry::Monads::Success via adapter
  end
end
```

### Basic Usage

```ruby
class CreateUser < TypedOperation::Base
  include Dry::Monads[:result]

  param :email, String

  def perform
    user = User.new(email: email)
    user.save ? Success(user) : Failure([:validation_error, user.errors])
  end
end

result = CreateUser.call(email: "test@example.com")
result.success?  # => true/false
result.value!    # Unwrap Success
result.failure   # Get Failure data
```

### Do Notation

Automatic error propagation with `yield`:

```ruby
class RegisterUser < ApplicationOperation
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)

  param :email, String
  param :password, String

  def perform
    user = yield create_user          # If Failure, returns immediately
    yield send_welcome_email(user)    # If Failure, returns immediately
    Success(user)                     # Only reached if all succeed
  end

  private

  def create_user
    user = User.new(email: email)
    user.save ? Success(user) : Failure([:validation_error, user.errors])
  end

  def send_welcome_email(user)
    UserMailer.welcome(user).deliver_later
    Success(user)
  rescue => e
    Failure([:email_error, e.message])
  end
end
```

### Composing Operations

```ruby
class CheckoutOperation < ApplicationOperation
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)

  param :cart_id, Integer
  param :user, User

  def perform
    cart = yield find_cart
    yield validate_cart(cart)
    order = yield create_order(cart)
    yield process_payment(order)
    Success(order)
  end
end
```

### Pattern Matching Results

```ruby
case CreateUser.call(email: "test@example.com")
in Success(user)
  puts "Created: #{user.email}"
in Failure[:validation_error, errors]
  puts "Validation: #{errors.join(', ')}"
in Failure[code, message]
  puts "Error: #{code} - #{message}"
end
```

### Error Format Convention

Use consistent tuple format:

```ruby
Failure([:not_found, "Resource not found"])
Failure([:validation_error, "Invalid input"])
Failure([:payment_failed, "Payment declined"])
```

### Maybe and Try

```ruby
# Maybe for optional values
class FindUser < ApplicationOperation
  include Dry::Monads[:maybe]
  param :user_id, Integer

  def perform
    user = User.find_by(id: user_id)
    user ? Some(user) : None()
  end
end

# Try for exception handling
class ParseJson < ApplicationOperation
  include Dry::Monads[:try]
  param :json_string, String

  def perform
    Try { JSON.parse(json_string) }.to_result
  end
end
```

---

## ActionPolicy

[ActionPolicy](https://actionpolicy.evilmartians.io/) provides authorization for operations.

**Note:** Only works with `TypedOperation::Base`, not `ImmutableBase`.

### Installation

```ruby
gem "action_policy"
```

### Setup

```ruby
require "typed_operation/action_policy_auth"

class ApplicationOperation < TypedOperation::Base
  include TypedOperation::ActionPolicyAuth

  param :initiator, optional(User)
end
```

### Basic Authorization

**With inline block:**
```ruby
class DeletePost < ApplicationOperation
  param :initiator, User
  param :post, Post

  action_type :delete

  authorized_via :initiator, record: :post do
    initiator.admin? || post.author == initiator
  end

  def perform
    post.destroy!
  end
end
```

**With policy class:**
```ruby
# app/policies/post_policy.rb
class PostPolicy < ApplicationPolicy
  def update?
    user.admin? || record.author == user
  end

  def delete?
    user.admin?
  end
end

# Operation
class UpdatePost < ApplicationOperation
  param :initiator, User
  param :post, Post
  param :title, String

  action_type :update

  authorized_via :initiator, with: PostPolicy, record: :post

  def perform
    post.update!(title: title)
  end
end
```

### authorized_via Options

```ruby
# Block authorization
authorized_via :initiator { initiator.admin? }

# With policy class
authorized_via :initiator, with: PostPolicy, record: :post

# Custom policy method
authorized_via :initiator, with: PostPolicy, to: :can_archive?, record: :post

# Multiple context params
authorized_via :current_owner, :new_owner { current_owner.active? && new_owner.active? }
```

**Key points:**
- `record:` uses the specified parameter or method to get the record
- Multiple context params supported for complex authorization
- Authorization is inherited by subclasses
- See [API reference](/api#actionpolicy-authorization) for complete details

### Requiring Authorization

Use `verify_authorized!` in your base class to require all subclasses configure authorization:

```ruby
class ApplicationOperation < TypedOperation::Base
  include TypedOperation::ActionPolicyAuth
  verify_authorized!
end
```

Operations without authorization will raise `MissingAuthentication`.

Override `on_authorization_failure(error)` for logging or side effects when authorization fails. See [API reference](/api#actionpolicy-authorization) for details.

### Handling Authorization Errors

```ruby
def update
  case Posts::UpdateOperation.call(post: @post, initiator: current_user, title: params[:title])
  in Success(post)
    redirect_to post
  in Failure[code, errors]
    render :edit, alert: errors
  end
rescue ActionPolicy::Unauthorized
  redirect_to @post, alert: "Permission denied"
end
```

### Limitations

1. **Cannot use with ImmutableBase** - only `TypedOperation::Base` supports authorization
2. **Authorization context must be a parameter** - cannot use methods like `current_user`

```ruby
# ✅ Works
param :initiator, User
authorized_via :initiator do; end

# ❌ Doesn't work
authorized_via :current_user do; end  # current_user is not a param
```

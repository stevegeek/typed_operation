# TypedOperation Integrations

## Rails Integration

### Installation with Generator

```bash
# Basic installation
bin/rails g typed_operation:install

# With Dry::Monads support
bin/rails g typed_operation:install --dry_monads

# With Action Policy support
bin/rails g typed_operation:install --action_policy

# With both
bin/rails g typed_operation:install --dry_monads --action_policy
```

### Generated ApplicationOperation

```ruby
# app/operations/application_operation.rb
class ApplicationOperation < ::TypedOperation::Base
  # Common parameters for all operations
  param :current_user, optional(User)
  
  # Custom DSL aliases
  class << self
    alias_method :arg, :positional_param
    alias_method :key, :named_param
  end
  
  private
  
  # Helper methods available to all operations
  def operation_key
    self.class.name.underscore
  end
end
```

### Generating Operations

```bash
# Generate in default location (app/operations)
bin/rails g typed_operation CreateUser

# Generate in custom location
bin/rails g typed_operation CreateUser --path=app/services/operations

# Creates:
# - app/operations/create_user.rb
# - test/operations/create_user_test.rb
```

### Rails Conventions

```ruby
class CreateUserOperation < ApplicationOperation
  key :email, String
  key :name, String
  key :role, String, default: "user"
  
  def perform
    user = User.create!(
      email: email,
      name: name,
      role: role
    )
    
    UserMailer.welcome(user).deliver_later
    user
  end
  
  private
  
  def prepare
    normalize_email!
  end
  
  def normalize_email!
    @attributes[:email] = email.downcase.strip
  end
end
```

## Dry::Monads Integration

### Basic Setup

```ruby
class ApplicationOperation < ::TypedOperation::Base
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)
  
  private
  
  def succeeded(value)
    Success(value)
  end
  
  def failed(error_code, message = "Operation failed", value = nil)
    Failure[error_code, message, value]
  end
end
```

### Do Notation Example

```ruby
class CreateAccountOperation < ApplicationOperation
  include Dry::Monads::Do.for(:perform, :create_user, :create_profile)
  
  key :organization_name, String
  key :admin_email, String
  key :admin_name, String
  
  def perform
    organization = yield create_organization
    admin = yield create_user(admin_email, admin_name, organization)
    profile = yield create_profile(admin)
    
    yield send_welcome_email(admin)
    
    Success(organization: organization, admin: admin)
  end
  
  private
  
  def create_organization
    org = Organization.create(name: organization_name)
    org.persisted? ? Success(org) : Failure[:invalid_organization, org.errors]
  end
  
  def create_user(email, name, org)
    user = org.users.create(email: email, name: name, role: "admin")
    user.persisted? ? Success(user) : Failure[:invalid_user, user.errors]
  end
  
  def create_profile(user)
    profile = user.create_profile
    profile ? Success(profile) : Failure[:profile_creation_failed]
  end
  
  def send_welcome_email(user)
    UserMailer.welcome(user).deliver_later
    Success()
  rescue => e
    Failure[:email_failed, e.message]
  end
end
```

### Result Handling

```ruby
result = CreateAccountOperation.call(
  organization_name: "Acme Corp",
  admin_email: "admin@acme.com",
  admin_name: "John Doe"
)

case result
in Success[organization:, admin:]
  redirect_to organization_path(organization)
in Failure[:invalid_organization, errors]
  render :new, errors: errors
in Failure[:invalid_user, errors]
  render :new, errors: errors
in Failure[code, message]
  flash[:error] = message
  render :new
end
```

## Action Policy Integration

### Setup

```ruby
require "typed_operation/action_policy_auth"

class ApplicationOperation < ::TypedOperation::Base
  include TypedOperation::ActionPolicyAuth
  
  # Require initiator for all operations
  param :initiator, User
end
```

### Basic Authorization

```ruby
class UpdatePostOperation < ApplicationOperation
  action_type :update
  
  key :post, Post
  key :title, String
  key :content, String
  
  # Block-based authorization
  authorized_via :initiator, record: :post do
    initiator.id == record.author_id || initiator.admin?
  end
  
  def perform
    post.update!(title: title, content: content)
  end
end
```

### Policy Class Authorization

```ruby
class DeletePostOperation < ApplicationOperation
  action_type :destroy
  
  key :post, Post
  
  class Policy < OperationPolicy
    def destroy?
      user.admin? || (user.id == record.author_id && !record.published?)
    end
    
    def destroy_published?
      user.admin?
    end
  end
  
  # Use policy class
  authorized_via :initiator, with: Policy, record: :post
  
  # Or use a different method
  # authorized_via :initiator, with: Policy, to: :destroy_published?, record: :post
  
  def perform
    post.destroy!
  end
end
```

### Authorization Hooks

```ruby
class SensitiveOperation < ApplicationOperation
  verify_authorized!  # Ensure all subclasses implement authorization
  
  action_type :execute
  
  authorized_via :initiator do
    initiator.admin?
  end
  
  def perform
    # Sensitive action
  end
  
  private
  
  # Hook for authorization failures
  def on_authorization_failure(error)
    Rails.logger.warn("Authorization failed for #{initiator.id}: #{error.message}")
    AuditLog.record_unauthorized_attempt(initiator, self.class.name)
  end
end
```

### Multiple Authorization Contexts

```ruby
class TransferOwnershipOperation < ApplicationOperation
  key :resource, Resource
  key :from_user, User
  key :to_user, User
  
  # Multiple authorization contexts
  authorized_via :initiator, :from_user, :to_user do
    initiator.admin? && 
    from_user.active? && 
    to_user.active? &&
    from_user.owns?(resource)
  end
  
  def perform
    resource.update!(owner: to_user)
  end
end
```

## Custom Integration Patterns

### Event Publishing

```ruby
class EventPublishingOperation < ApplicationOperation
  def after_execute_operation(result)
    publish_event(result) if succeeded?(result)
    super
  end
  
  private
  
  def publish_event(result)
    EventBus.publish(
      event_name,
      payload: event_payload(result),
      metadata: event_metadata
    )
  end
  
  def event_name
    "#{operation_key}.executed"
  end
  
  def succeeded?(result)
    result.is_a?(Dry::Monads::Success)
  end
end
```

### Database Transactions

```ruby
class TransactionalOperation < ApplicationOperation
  def execute_operation
    ApplicationRecord.transaction do
      super
    end
  rescue ActiveRecord::Rollback => e
    failed(:transaction_rollback, e.message)
  end
end
```

### Async Job Integration

```ruby
class AsyncOperation < ApplicationOperation
  def self.perform_async(...)
    AsyncOperationJob.perform_later(
      operation_class: name,
      arguments: [...]
    )
  end
end

class AsyncOperationJob < ApplicationJob
  def perform(operation_class:, arguments:)
    operation_class.constantize.call(*arguments)
  end
end
```

### Instrumentation

```ruby
class InstrumentedOperation < ApplicationOperation
  def execute_operation
    ActiveSupport::Notifications.instrument(
      "operation.execute",
      operation: self.class.name,
      params: attributes
    ) do
      super
    end
  end
end
```
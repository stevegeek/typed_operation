---
title: Best Practices
nav_order: 4
---

# Best Practices

Guidelines for testing, error handling, and organizing operations.

## When to Use Operations

**✅ Good candidates:**
- Complex business logic with multiple steps
- Type-safe inputs with explicit contracts
- Reusable logic across controllers, jobs, services
- Coordination between multiple models/services
- Authorization checks

**❌ Not ideal:**
- Simple CRUD with no business logic (use ActiveRecord)
- Single-line transformations
- Framework-specific concerns (callbacks, validations)
- View logic (use helpers/presenters)

## Design Principles

### Naming Conventions

Use verb-noun format:
```ruby
# ✅ Good
CreateUserOperation
ProcessRefundOperation
GenerateReportOperation

# ❌ Bad
UserCreator
RefundProcessor
```

### Single Responsibility

Split large operations:
```ruby
# ✅ Good - Focused operations
class ProcessOrderOperation < ApplicationOperation
  include Dry::Monads::Do.for(:perform)

  def perform
    yield ChargePaymentOperation.call(order: order)
    yield UpdateInventoryOperation.call(order: order)
    yield SendConfirmationOperation.call(order: order)
    Success(order)
  end
end
```

### Parameter Design

```ruby
class SearchUsersOperation < TypedOperation::Base
  param :query, String
  param :limit, Integer, default: 25
  param :offset, Integer, default: 0
  param :sort_by, optional(String)
  param :filters, Hash, default: -> { {} }  # Use proc for mutable defaults
end
```

---

## Testing

### Basic Operation Tests (RSpec)

```ruby
RSpec.describe Users::CreateOperation do
  it 'creates a user' do
    result = described_class.call(email: 'test@example.com', name: 'Test')
    expect(result.email).to eq('test@example.com')
  end

  it 'raises type error for invalid input' do
    expect {
      described_class.call(email: nil, name: 'Test')
    }.to raise_error(Literal::TypeError)
  end
end
```

### Testing with Dry::Monads

```ruby
RSpec.describe Orders::ProcessOperation do
  let(:order) { create(:order) }

  context 'when successful' do
    it 'returns Success' do
      result = described_class.call(order: order)
      expect(result).to be_success
      expect(result.value!).to eq(order)
    end
  end

  context 'when payment fails' do
    before { allow(PaymentGateway).to receive(:charge).and_return(false) }

    it 'returns Failure with error code' do
      result = described_class.call(order: order)
      expect(result).to be_failure
      code, _message = result.failure
      expect(code).to eq(:payment_failed)
    end
  end
end
```

### Testing Composed Operations

```ruby
RSpec.describe RegisterUserOperation do
  it 'stops on first failure' do
    allow(CreateUserOperation).to receive(:call).and_return(Failure(:error))
    allow(SendWelcomeEmailOperation).to receive(:call)

    result = described_class.call(email: 'test@example.com', password: 'pass')

    expect(result).to be_failure
    expect(SendWelcomeEmailOperation).not_to have_received(:call)
  end
end
```

### Mocking Dependencies

```ruby
# Inject dependencies as params for testability
class ProcessPaymentOperation < TypedOperation::Base
  param :order, Order
  param :gateway, Object, default: -> { PaymentGateway.new }

  def perform
    gateway.charge(order.total)
  end
end

RSpec.describe ProcessPaymentOperation do
  it 'uses gateway' do
    mock_gateway = instance_double(PaymentGateway, charge: true)
    described_class.call(order: create(:order), gateway: mock_gateway)
    expect(mock_gateway).to have_received(:charge)
  end
end
```

### Testing Partial Application

```ruby
RSpec.describe SendEmailOperation do
  it 'pre-fills parameters' do
    base_op = described_class.with(from: 'noreply@example.com')
    allow(Mailer).to receive(:send_email)

    base_op.call(to: 'user@example.com', subject: 'Test', body: 'Body')

    expect(Mailer).to have_received(:send_email)
      .with(hash_including(from: 'noreply@example.com'))
  end
end
```

### Testing Authorization

```ruby
RSpec.describe Posts::UpdateOperation do
  it 'raises error when unauthorized' do
    allow_any_instance_of(PostPolicy).to receive(:update?).and_return(false)

    expect {
      described_class.call(post: create(:post), initiator: create(:user), title: 'New')
    }.to raise_error(ActionPolicy::Unauthorized)
  end
end
```

---

## Error Handling

### Choosing Between Exceptions and Results

**Use exceptions for:**
- Programming errors (type errors, nil references)
- Invariant violations (data integrity)
- Configuration issues
- Truly exceptional cases that should halt execution

**Use Result types for:**
- Expected failure cases (validation, authorization)
- Business rule violations
- External service failures
- Flows where caller needs granular error handling

### Custom Exception Classes

Define operation-specific exceptions for domain clarity:

```ruby
class TransferFundsOperation < TypedOperation::Base
  class InsufficientFundsError < StandardError; end
  class AccountFrozenError < StandardError; end

  param :from_account, Account
  param :to_account, Account
  param :amount_cents, Integer

  def perform
    raise InsufficientFundsError if from_account.balance_cents < amount_cents
    raise AccountFrozenError if from_account.frozen?

    # ... perform transfer
  end
end
```

### Result Type Patterns

Use symbolic error codes for pattern matching:

```ruby
class AuthenticateUserOperation < TypedOperation::Base
  include Dry::Monads[:result]

  param :email, String
  param :password, String

  def perform
    user = User.find_by(email: email)
    return Failure(:user_not_found) unless user
    return Failure(:account_locked) if user.locked?
    return Failure(:invalid_password) unless user.authenticate(password)
    Success(user)
  end
end
```

### Mixing Exceptions and Results

Use exceptions in `prepare` for invariants, Results in `perform` for business logic:

```ruby
class CreateBookingOperation < TypedOperation::Base
  include Dry::Monads[:result]

  param :room, Room
  param :start_date, Date
  param :end_date, Date

  def prepare
    raise ArgumentError, "End date must be after start" if end_date <= start_date
  end

  def perform
    return Failure(:room_unavailable) unless room.available?(start_date, end_date)
    booking = Booking.create!(room: room, start_date: start_date, end_date: end_date)
    Success(booking)
  end
end
```

### Retry Strategies

```ruby
class SendNotificationOperation < TypedOperation::Base
  include Dry::Monads[:result]

  param :user, User
  param :max_retries, Integer, default: 3

  def perform
    retries = 0
    begin
      NotificationService.send(user)
      Success(true)
    rescue NotificationService::TemporaryError
      retries += 1
      retry if retries < max_retries
      Failure(:max_retries_exceeded)
    end
  end
end
```

---

## Organizing Operations

### Directory Structure

```
app/operations/
├── application_operation.rb
├── users/
│   ├── create_operation.rb
│   └── update_operation.rb
└── orders/
    ├── process_operation.rb
    └── refund_operation.rb
```

### Shared Base Classes

```ruby
class ApplicationOperation < TypedOperation::Base
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)
end

module Users
  class BaseOperation < ApplicationOperation
    param :current_user, optional(User)
  end
end
```

### Common Mixins

```ruby
module Paginatable
  extend ActiveSupport::Concern

  included do
    param :page, Integer, default: 1
    param :per_page, Integer, default: 25
  end

  def pagination_offset
    (page - 1) * per_page
  end
end

class SearchUsersOperation < ApplicationOperation
  include Paginatable
  param :query, String

  def perform
    User.where("name LIKE ?", "%#{query}%")
        .limit(per_page)
        .offset(pagination_offset)
  end
end
```

---

## Common Patterns

### Builder Pattern

```ruby
report_builder = BuildReportOperation.with(user: current_user, start_date: 1.month.ago)

pdf_report = report_builder.call(end_date: Date.today, format: "pdf")
csv_report = report_builder.call(end_date: Date.today, format: "csv")
```

### Query Object

```ruby
class FindActiveUsersOperation < TypedOperation::Base
  param :role, optional(String)
  param :limit, Integer, default: 100

  def perform
    scope = User.active
    scope = scope.where(role: role) if role
    scope.limit(limit)
  end
end
```

### Service Wrapper

```ruby
class FetchWeatherDataOperation < TypedOperation::Base
  include Dry::Monads[:result]
  param :city, String

  def perform
    response = WeatherAPI.fetch(city: city)
    response.success? ? Success(response.data) : Failure(:api_error)
  rescue => e
    Failure(:network_error)
  end
end
```

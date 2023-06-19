# TypedOperation

An implementation of a Command pattern, which is callable, and can be partially applied (curried).

Inputs to the operation are specified as typed attributes using the `param` method.

Results of the operation are a type of `Dry::Monads::Result` object.

### Examples:

A base operation class:

```ruby
class ApplicationOperation < ::TypedOperation::Base
  param :initiator, ::RegisteredUser, allow_nil: true

  private

  def succeeded(value)
    Success(value)
  end

  def failed_with_value(value, message: "Operation failed", error_code: nil)
    failed(error_code || self.class.operation_key, message, value)
  end

  def failed_with_message(message, error_code: nil)
    failed(error_code || self.class.operation_key, message)
  end

  def failed(error_code, message = "Operation failed", value = nil)
    Failure[error_code, message, value]
  end

  def failed_with_code_and_value(error_code, value, message: "Operation failed")
    failed(error_code, message, value)
  end
end

```

A simple operation:

```ruby
class TestOperation < ::ApplicationOperation
  param :foo, String
  param :bar, String
  param :baz, String, convert: true

  def prepare
    # to setup (optional)
    puts "lets go!"
  end
  
  def call
    succeeded("It worked!")
    # failed_with_message("It failed!")
  end
end
```

```ruby
TestOperation.(foo: "1", bar: "2", baz: 3)
# => Success("It worked!")

TestOperation.with(foo: "1").with(bar: "2")
# => #<TypedOperation::PartiallyApplied:0x000000014a655310 @applied_args={:foo=>"1", :bar=>"2"}, @operation=TestOperation>

TestOperation.with(foo: "1").with(bar: "2").with(baz: 3)
# => <TypedOperation::Prepared:0x000000012dac6498 @applied_args={:foo=>"1", :bar=>"2", :baz=>3}, @operation=TestOperation>

TestOperation.with(foo: "1").with(bar: "2").with(baz: 3).call
# => Success("It worked!")

TestOperation.with(foo: "1").with(bar: "2").with(baz: 3).operation
# => <TestOperation:0x000000014a0048a8 @__attributes=#<TestOperation::TypedSchema foo="1" bar="2" baz="3">>
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem "typed_operation"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install typed_operation
```

## Add an `ApplicationOperation` to your project

```ruby
bin/rails g typed_operation:install
```

## Generate a new Operation

```ruby
bin/rails g typed_operation TestOperation
```

You can optionally specify the directory to generate the operation in:

```ruby
bin/rails g typed_operation TestOperation --path=app/operations
```

The default path is `app/operations`.

## Contributing
Contribution directions go here.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

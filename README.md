# TypedOperation

An implementation of a Command pattern, which is callable, and can be partially applied (curried).

Inputs to the operation are specified as typed attributes using the `param` method.

Result format of the operation is up to you, but plays nicely with `Dry::Monads`. 

### Examples:

#### A simple operation:

```ruby
class TestOperation < ::TypedOperation::Base
  param :foo, String
  param :bar, String
  param :baz, String do |value|
    value.to_s
  end

  def prepare
    # to setup (optional)
    puts "lets go!"
  end
  
  def call
    "It worked!"
  end
end
```

```ruby
TestOperation.(foo: "1", bar: "2", baz: 3)
# => "It worked!"

TestOperation.with(foo: "1").with(bar: "2")
# => #<TypedOperation::PartiallyApplied:0x000000014a655310 @applied_args={:foo=>"1", :bar=>"2"}, @operation=TestOperation>

TestOperation.with(foo: "1").with(bar: "2").with(baz: 3)
# => <TypedOperation::Prepared:0x000000012dac6498 @applied_args={:foo=>"1", :bar=>"2", :baz=>3}, @operation=TestOperation>

TestOperation.with(foo: "1").with(bar: "2").with(baz: 3).call
# => "It worked!"

TestOperation.with(foo: "1").with(bar: "2").call(baz: 3)
# => "It worked!"

# > TestOperation.with(foo: "1").with(bar: "2").call
# => Raises an error because it is PartiallyApplied and so can't be called (it is missing required args)

TestOperation.with(foo: "1").with(bar: "2").with(baz: 3).operation
# same as > TestOperation.new(foo: "1", bar: "2", baz: 3)
# => <TestOperation:0x000000014a0048a8 @__attributes=#<TestOperation::TypedSchema foo="1" bar="2" baz="3">>

# > TestOperation.with(foo: "1").with(bar: "2").operation
# => Raises an error because it is PartiallyApplied so operation can't be instantiated
```

#### `ApplicationOperation` in a Rails app

This is an example of a `ApplicationOperation` in a Rails app that uses `Dry::Monads`:

```ruby
# frozen_string_literal: true

class ApplicationOperation < ::TypedOperation::Base
  include Dry::Monads[:result, :do]
  
  param :initiator, ::User, optional: true

  private

  def succeeded(value)
    Success(value)
  end

  def failed_with_value(value, message: "Operation failed", error_code: nil)
    failed(error_code || operation_key, message, value)
  end

  def failed_with_message(message, error_code: nil)
    failed(error_code || operation_key, message)
  end

  def failed(error_code, message = "Operation failed", value = nil)
    Failure[error_code, message, value]
  end

  def failed_with_code_and_value(error_code, value, message: "Operation failed")
    failed(error_code, message, value)
  end

  def operation_key
    self.class.operation_key
  end
end
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

### Add an `ApplicationOperation` to your project

```ruby
bin/rails g typed_operation:install
```

Use the `--dry_monads` switch to `include Dry::Monads[:result]` into your `ApplicationOperation` (don't forget to also 
add `gem "dry-monads"` to your Gemfile)

```ruby
bin/rails g typed_operation:install --dry_monads
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

The generator will also create a test file.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stevegeek/typed_operation. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/stevegeek/typed_operation/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TypedOperation project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/stevegeek/typed_operation/blob/master/CODE_OF_CONDUCT.md).

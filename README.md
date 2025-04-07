# TypedOperation

An implementation of a Command pattern, which is callable, and can be partially applied.

Inputs to the operation are specified as typed attributes (uses [`literal`](https://github.com/joeldrapper/literal)).

Type of result of the operation is up to you, eg you could use [`Dry::Monads`](https://dry-rb.org/gems/dry-monads/1.3/).

## Features

- Operations can be **partially applied** or **curried**
- Operations are **callable**
- Operations can be **pattern matched** on
- Parameters:
  - specified with **type constraints** (uses `literal` gem)
  - can be **positional** or **named**
  - can be **optional**, or have **default** values
  - can be **coerced** by providing a block

### Example

```ruby
class ShelveBookOperation < ::TypedOperation::Base
  # Parameters can be specified with `positional_param`/`named_param` or directly with the
  # underlying `param` method.
  
  # Note that you may also like to simply alias the param methods to your own preferred names:
  # `positional`/`named` or `arg`/`key` for example.
  
  # A positional parameter (positional argument passed to the operation when creating it).
  positional_param :title, String
  # Or if you prefer:
  #   `param :title, String, positional: true`
  
  # A named parameter (keyword argument passed to the operation when creating it).
  named_param :description, String
  # Or if you prefer:
  #   `param :description, String`

  # `param` creates named parameters by default
  param :author_id, Integer, &:to_i
  param :isbn, String
  
  # Optional parameters are specified by wrapping the type constraint in the `optional` method, or using the `optional:` option
  param :shelf_code, optional(Integer)
  # Or if you prefer:
  #   `named_param :shelf_code, Integer, optional: true`

  param :category, String, default: "unknown".freeze

  # optional hook called when the operation is initialized, and after the parameters have been set
  def prepare
    raise ArgumentError, "ISBN is invalid" unless valid_isbn?
  end

  # optionally hook in before execution ... and call super to allow subclasses to hook in too
  def before_execute_operation
    # ...
    super
  end

  # The 'work' of the operation, this is the main body of the operation and must be implemented
  def perform
    "Put away '#{title}' by author ID #{author_id}#{shelf_code ? " on shelf #{shelf_code}" : "" }"
  end

  # optionally hook in after execution ... and call super to allow subclasses to hook in too
  def after_execute_operation(result)
    # ...
    super
  end
  
  private

  def valid_isbn?
    # ...
    true
  end
end

shelve = ShelveBookOperation.new("The Hobbit", description: "A book about a hobbit", author_id: "1", isbn: "978-0261103283")
# => #<ShelveBookOperation:0x0000000108b3e490 @attributes={:title=>"The Hobbit", :description=>"A book about a hobbit", :author_id=>1, :isbn=>"978-0261103283", :shelf_code=>nil, :category=>"unknown"}, ...

shelve.call
# => "Put away 'The Hobbit' by author ID 1"

shelve = ShelveBookOperation.with("The Silmarillion", description: "A book about the history of Middle-earth", shelf_code: 1)
# => #<TypedOperation::PartiallyApplied:0x0000000103e6f560 ...

shelve.call(author_id: "1", isbn: "978-0261102736")
# => "Put away 'The Silmarillion' by author ID 1 on shelf 1"

curried = shelve.curry
# => #<TypedOperation::Curried:0x0000000108d98a10 ...

curried.(1).("978-0261102736")
# => "Put away 'The Silmarillion' by author ID 1 on shelf 1"

shelve.call(author_id: "1", isbn: false)
# => Raises an error because isbn is invalid
# :in `initialize': Expected `false` to be of type: `String`. (Literal::TypeError)
```

### Partially applying parameters

Operations can also be partially applied and curried:

```ruby
class TestOperation < ::TypedOperation::Base
  param :foo, String, positional: true
  param :bar, String
  param :baz, String, &:to_s

  def perform = "It worked! (#{foo}, #{bar}, #{baz})"
end

# Invoking the operation directly
TestOperation.("1", bar: "2", baz: 3)
# => "It worked! (1, 2, 3)"

# Partial application of parameters
partially_applied = TestOperation.with("1").with(bar: "2")
# => #<TypedOperation::PartiallyApplied:0x0000000110270248 @keyword_args={:bar=>"2"}, @operation_class=TestOperation, @positional_args=["1"]>

# You can partially apply more than one parameter at a time, and chain calls to `.with`.
# With all the required parameters set, the operation is 'prepared' and can be instantiated and called
prepared = TestOperation.with("1", bar: "2").with(baz: 3)
# => #<TypedOperation::Prepared:0x0000000110a9df38 @keyword_args={:bar=>"2", :baz=>3}, @operation_class=TestOperation, @positional_args=["1"]>

# A 'prepared' operation can instantiated & called
prepared.call
# => "It worked! (1, 2, 3)"

# You can provide additional parameters when calling call on a partially applied operation
partially_applied.call(baz: 3)
# => "It worked! (1, 2, 3)"

# Partial application can be done using `.with or `.[]`
TestOperation.with("1")[bar: "2", baz: 3].call
# => "It worked! (1, 2, 3)"

# Currying an operation, note that *all required* parameters must be provided an argument in order  
TestOperation.curry.("1").("2").(3)
# => "It worked! (1, 2, 3)"

# You can also curry from an already partially applied operation, so you can set optional named parameters first.
# Note currying won't let you set optional positional parameters.
partially_applied = TestOperation.with("1")
partially_applied.curry.("2").(3)
# => "It worked! (1, 2, 3)"

# > TestOperation.with("1").with(bar: "2").call
# => Raises an error because it is PartiallyApplied and so can't be called (it is missing required args)
#      "Cannot call PartiallyApplied operation TestOperation (key: test_operation), are you expecting it to be Prepared? (TypedOperation::MissingParameterError)"

TestOperation.with("1").with(bar: "2").with(baz: 3).operation
# same as > TestOperation.new("1", bar: "2", baz: 3)
# => <TestOperation:0x000000014a0048a8 ...>

# > TestOperation.with(foo: "1").with(bar: "2").operation
# => Raises an error because it is PartiallyApplied so operation can't be instantiated
#      "Cannot instantiate Operation TestOperation (key: test_operation), as it is only partially applied. (TypedOperation::MissingParameterError)"
```

## Documentation

### Create an operation (subclass `TypedOperation::Base` or `TypedOperation::ImmutableBase`)

Create an operation by subclassing `TypedOperation::Base` or `TypedOperation::ImmutableBase` and specifying the parameters the operation requires.

- `TypedOperation::Base` (uses `Literal::Struct`) is the parent class for an operation where the arguments are potentially mutable (ie not frozen).
  No attribute writer methods are defined, so the arguments can not be changed after initialization, but the values passed in are not guaranteed to be frozen.
- `TypedOperation::ImmutableBase` (uses `Literal::Data`) is the parent class for an operation where the operation instance is frozen on initialization,
  thus giving a somewhat stronger immutability guarantee.

> Note: you cannot include `TypedOperation::ActionPolicyAuth` into a `TypedOperation::ImmutableBase`.

The subclass must implement the `#perform` method which is where the operations main work is done.

The operation can also implement:

- `#prepare` - called when the operation is initialized, and after the parameters have been set
- `#before_execute_operation` - optionally hook in before execution ... and call super to allow subclasses to hook in too
- `#after_execute_operation` - optionally hook in after execution ... and call super to allow subclasses to hook in too
  
```ruby
# optionally hook in before execution...
def before_execute_operation
  # Remember to call super
  super
end

def perform
  # ... implement me!
end

# optionally hook in after execution...
def after_execute_operation(result)
  # Remember to call super, note the result is passed in and the return value of this method is the result of the operation
  # thus allowing you to modify the result if you wish
  super
end
```

### Specifying parameters (using `.param`)

Parameters are specified using the provided class methods (`.positional_param` and `.named_param`), 
or using the underlying `.param` method.

Types are specified using the `literal` gem. In many cases this simply means providing the class of the
expected type, but there are also some other useful types provided by `literal` (eg `Union`).

These can be either accessed via the `Literal` module, eg `Literal::Types::BooleanType`:

```ruby
class MyOperation < ::TypedOperation::Base
  param :name, String
  param :age, Integer, optional: true
  param :choices, Literal::Types::ArrayType.new(String)
  param :chose, Literal::Types::BooleanType
end

MyOperation.new(name: "bob", choices: ["st"], chose: true)
```

or by including the `Literal::Types` module into your operation class, and using the aliases provided:

```ruby
class MyOperation < ::TypedOperation::Base
  include Literal::Types
  
  param :name, String
  param :age, _Nilable(Integer) # optional can also be specifed using `.optional`
  param :choices, _Array(String)
  param :chose, _Boolean
end
```

Type constraints can be modified to make the parameter optional using `.optional`.

#### Your own aliases

Note that you may also like to alias the param methods to your own preferred names in a common base operation class.

Some possible aliases are:
- `positional`/`named`
- `arg`/`key`
 
For example:

```ruby
class ApplicationOperation < ::TypedOperation::Base
  class << self
    alias_method :arg, :positional_param
    alias_method :key, :named_param
  end
end

class MyOperation < ApplicationOperation
  arg :name, String
  key :age, Integer
end

MyOperation.new("Steve", age: 20)
```

#### Positional parameters (`positional: true` or `.positional_param`)

Defines a positional parameter (positional argument passed to the operation when creating it).

The following are equivalent:

- `param <param_name>, <type>, positional: true, <**options>`
- `positional_param <param_name>, <type>, <**options>`

The `<para_name>` is a symbolic name, used to create the accessor method, and when deconstructing to a hash.

The `<type>` constraint provides the expected type of the parameter (the type is a type signature compatible with `literal`).

The `<options>` are:
- `default:` - a default value for the parameter (can be a proc or a frozen value)
- `optional:` - a boolean indicating whether the parameter is optional (default: false). Note you may prefer to use the 
  `.optional` method instead of this option.

**Note** when positional arguments are provided to the operation, they are matched in order of definition or positional
params. Also note that you cannot define required positional parameters after optional ones.

Eg

```ruby
class MyOperation < ::TypedOperation::Base
  positional_param :name, String, positional: true
  # Or alternatively => `param :name, String, positional: true` 
  positional_param :age, Integer, default: -> { 0 }
  
  def perform
    puts "Hello #{name} (#{age})"
  end
end

MyOperation.new("Steve").call 
# => "Hello Steve (0)"

MyOperation.with("Steve").call(20)
# => "Hello Steve (20)"
```

#### Named (keyword) parameters

Defines a named parameter (keyword argument passed to the operation when creating it).

The following are equivalent:
- `param <param_name>, <type>, <**options>`
- `named_param <param_name>, <type>, <**options>`

The `<para_name>` is a symbol, used as parameter name for the keyword arguments in the operation constructor, to
create the accessor method and when deconstructing to a hash.

The type constraint and options are the same as for positional parameters.

```ruby
class MyOperation < ::TypedOperation::Base
  named_param :name, String
  # Or alternatively => `param :name, String` 
  named_param :age, Integer, default: -> { 0 }
  
  def perform
    puts "Hello #{name} (#{age})"
  end
end

MyOperation.new(name: "Steve").call 
# => "Hello Steve (0)"

MyOperation.with(name: "Steve").call(age: 20)
# => "Hello Steve (20)"
```

#### Using both positional and named parameters

You can use both positional and named parameters in the same operation.

```ruby
class MyOperation < ::TypedOperation::Base
  positional_param :name, String
  named_param :age, Integer, default: -> { 0 }
  
  def perform
    puts "Hello #{name} (#{age})"
  end
end

MyOperation.new("Steve").call 
# => "Hello Steve (0)"

MyOperation.new("Steve", age: 20).call
# => "Hello Steve (20)"

MyOperation.with("Steve").call(age: 20)
# => "Hello Steve (20)"
```

#### Optional parameters (using `optional:` or `.optional`)

Optional parameters are ones that do not need to be specified for the operation to be instantiated.

An optional parameter can be specified by:
- using the `optional:` option
- using the `.optional` method around the type constraint

```ruby
class MyOperation < ::TypedOperation::Base
  param :name, String
  param :age, Integer, optional: true
  param :nickname, optional(String)
  # ...
end

MyOperation.new(name: "Steve")
MyOperation.new(name: "Steve", age: 20)
MyOperation.new(name: "Steve", nickname: "Steve-o")
```

This `.optional` class method effectively makes the type signature a union of the provided type and `NilClass`.

#### Coercing parameters

You can specify a block after a parameter definition to coerce the argument value.

```ruby
param :name, String, &:to_s
param :choice, Literal::Types::BooleanType do |v|
  v == "y"
end
```

#### Default values (with `default:`)

You can specify a default value for a parameter using the `default:` option.

The default value can be a proc or a frozen value. If the value is specified as `nil` then the default value is literally nil and the parameter is optional.

```ruby
param :name, String, default: "Steve".freeze
param :age, Integer, default: -> { rand(100) }
```

If using the directive `# frozen_string_literal: true` then you string values are frozen by default.

### Partially applying (fixing parameters) on an operation (using `.with`)

`.with(...)` creates a partially applied operation with the provided parameters.

It is aliased to `.[]` for an alternative syntax.

Note that `.with` can take both positional and keyword arguments, and can be chained.

**An important caveat about partial application is that type checking is not done until the operation is instantiated**

```ruby
MyOperation.new(123)
# => Raises an error as the type of the first parameter is incorrect:
#    Expected `123` to be of type: `String`. (Literal::TypeError)

op = MyOperation.with(123)
# => #<TypedOperation::Prepared:0x000000010b1d3358 ...
#     Does **not raise** an error, as the type of the first parameter is not checked until the operation is instantiated

op.call # or op.operation
# => Now raises an error as the type of the first parameter is incorrect and operation is instantiated
```

### Calling an operation (using `.call`)

An operation can be invoked by:

- instantiating it with at least required params and then calling the `#call` method on the instance
- once a partially applied operation has been prepared (all required parameters have been set), the call
  method on `TypedOperation::Prepared` can be used to instantiate and call the operation.
- once an operation is curried, the `#call` method on last TypedOperation::Curried in the chain will invoke the operation
- calling `#call` on a partially applied operation and passing in any remaining required parameters
- calling `#execute_operation` on an operation instance (this is the method that is called by `#call`)

See the many examples in this document.

### Pattern matching on an operation

`TypedOperation::Base` and `TypedOperation::PartiallyApplied` implement `deconstruct` and `deconstruct_keys` methods,
so they can be pattern matched against.

```ruby
case MyOperation.new("Steve", age: 20)
in MyOperation[name, age]
  puts "Hello #{name} (#{age})"
end

case MyOperation.new("Steve", age: 20)
in MyOperation[name:, age: 20]
  puts "Hello #{name} (#{age})"
end
```

### Introspection of parameters & other methods

#### `.to_proc`

Get a proc that calls `.call(...)`


#### `#to_proc`

Get a proc that calls the `#call` method on an operation instance

#### `.prepared?`

Check if an operation is prepared

#### `.operation`

Return an operation instance from a Prepared operation. Will raise if called on a PartiallyApplied operation

#### `.positional_parameters`

List of the names of the positional parameters, in order

#### `.keyword_parameters`

List of the names of the keyword parameters

#### `.required_positional_parameters`

List of the names of the required positional parameters, in order

#### `.required_keyword_parameters`

List of the names of the required keyword parameters

#### `.optional_positional_parameters`

List of the names of the optional positional parameters, in order

#### `.optional_keyword_parameters`

List of the names of the optional keyword parameters


### Using with Rails

You can use the provided generator to create an `ApplicationOperation` class in your Rails project.

You can then extend this to add extra functionality to all your operations.

This is an example of a `ApplicationOperation` in a Rails app that uses `Dry::Monads`:

```ruby
# frozen_string_literal: true

class ApplicationOperation < ::TypedOperation::Base
  # We choose to use dry-monads for our operations, so include the required modules
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform)
  
  class << self
    # Setup our own preferred names for the DSL methods
    alias_method :positional, :positional_param
    alias_method :named, :named_param
  end
  
  # Parameters common to all Operations in this application
  named :initiator, optional(::User)

  private

  # We setup some helper methods for our operations to use
  
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
    self.class.name
  end
end
```

### Using with Action Policy (`action_policy` gem)

> Note, this optional feature requires the `action_policy` gem to be installed and does not yet work with `ImmutableBase`.

Add `TypedOperation::ActionPolicyAuth` to your `ApplicationOperation` (first `require` the module):

```ruby
require "typed_operation/action_policy_auth"

class ApplicationOperation < ::TypedOperation::Base
  # ...
  include TypedOperation::ActionPolicyAuth

  # You can specify a parameter to take the authorization context object, eg a user (can also be optional if some
  # operations don't require authorization)
  param :initiator, ::User # or optional(::User)
end
```

#### Specify the action with `.action_type`

Every operation must define what action_type it is, eg:

```ruby
class MyUpdateOperation < ApplicationOperation
  action_type :update
end
```

Any symbol can be used as the `action_type` and this is by default used to determine which policy method to call.

#### Configuring auth with `.authorized_via`

`.authorized_via` is used to specify how to authorize the operation. You must specify the name of a parameter
for the policy authorization context. You can also specify multiple parameters if you wish.

You can then either provide a block with the logic to perform the authorization check, or provide a policy class.

The `record:` option lets you provide the name of the parameter which will be passed as the policy 'record'.

For example:

```ruby
class MyUpdateOperation < ApplicationOperation
  param :initiator, ::AdminUser
  param :order, ::Order
  
  action_type :update
  
  authorized_via :initiator, record: :order do
    # ... the permissions check, admin users can edit orders that are not finalized
    initiator.admin? && !record.finalized
  end
  
  def perform
    # ...
  end
end
```

You can instead provide a policy class implementation:

```ruby
class MyUpdateOperation < ApplicationOperation
  action_type :update
  
  class MyPolicyClass < OperationPolicy
    # The action_type defined on the operation determines which method is called on the policy class
    def update?
      # ... the permissions check
      initiator.admin?
    end
    
    # def my_check?
    #   # ... the permissions check
    # end
  end
  
  authorized_via :initiator, with: MyPolicyClass
  
  # It is also possible to specify which policy method to call
  #      authorized_via :initiator, with: MyPolicyClass, to: :my_check?
end
```

with multiple parameters:

```ruby
class MyUpdateOperation < ApplicationOperation
  # ...
  param :initiator, ::AdminUser
  param :user, ::User
  
  authorized_via :initiator, :user do
    initiator.active? && user.active?
  end
  
  # ...
end
```

#### `.verify_authorized!`

To ensure that subclasses always implement authentication you can add a call to `.verify_authorized!` to your base
operation class.

This will cause the execution of any subclasses to fail if no authorization is performed.

```ruby
class MustAuthOperation < ApplicationOperation
  verify_authorized!
end

class MyUpdateOperation < MustAuthOperation
  def perform
    # ...
  end
end

MyUpdateOperation.call # => Raises an error that MyUpdateOperation does not perform any authorization
```

#### `#on_authorization_failure(err)`

A hook is provided to allow you to do some work on an authorization failure.

Simply override the `#on_authorization_failure(err)` method in your operation.

```ruby
class MyUpdateOperation < ApplicationOperation
  action_type :update
  
  authorized_via :initiator do
    # ... the permissions check
    initiator.admin?
  end
  
  def perform
    # ...
  end
  
  def on_authorization_failure(err)
    # ... do something with the error, eg logging
  end
end
```

Note you are provided the ActionPolicy error object, but you cannot stop the error from being re-raised.

### Using with `Dry::Monads`

As per the example in [`Dry::Monads` documentation](https://dry-rb.org/gems/dry-monads/1.0/do-notation/)

```ruby
class MyOperation < ::TypedOperation::Base
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:perform, :create_account)

  param :account_name, String
  param :owner, ::Owner
  
  def perform
    account = yield create_account(account_name)
    yield AnotherOperation.call(account, owner)

    Success(account)
  end

  private
  
  def create_account(account_name)
    # returns Success(account) or Failure(:cant_create)
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

Use the `--action_policy` switch to add the `TypedOperation::ActionPolicyAuth` module to your `ApplicationOperation`
(and you will also need to add `gem "action_policy"` to your Gemfile).

```ruby
bin/rails g typed_operation:install --dry_monads --action_policy
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

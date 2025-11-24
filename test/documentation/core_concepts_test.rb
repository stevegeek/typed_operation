# frozen_string_literal: true

require "test_helper"

# Tests for examples from core documentation
class CoreConceptsTest < Minitest::Test
  # From getting-started.md - Basic operation
  class GreetUserOperation < TypedOperation::Base
    param :name, String
    param :greeting, String, default: "Hello"

    def perform
      "#{greeting}, #{name}!"
    end
  end

  def test_greet_user_basic_example
    result = GreetUserOperation.call(name: "Alice")
    assert_equal "Hello, Alice!", result
  end

  def test_greet_user_with_custom_greeting
    result = GreetUserOperation.call(name: "Bob", greeting: "Hi")
    assert_equal "Hi, Bob!", result
  end

  # From parameters.md - Optional parameters
  class CreateUserOperation < TypedOperation::Base
    include Literal::Types

    param :email, String
    param :name, String
    param :role, optional(String)

    def perform
      { email: email, name: name, role: role }
    end
  end

  def test_create_user_with_optional_param
    result = CreateUserOperation.call(email: "test@example.com", name: "Test", role: "admin")
    assert_equal "admin", result[:role]
  end

  def test_create_user_without_optional_param
    result = CreateUserOperation.call(email: "test@example.com", name: "Test")
    assert_nil result[:role]
  end

  # From parameters.md - Type validation
  def test_type_validation_raises_error
    assert_raises Literal::TypeError do
      GreetUserOperation.call(name: 123) # Integer instead of String
    end
  end

  # From executing-operations.md - Different calling styles
  def test_calling_with_positional_hash
    result = GreetUserOperation.call(name: "Charlie")
    assert_equal "Hello, Charlie!", result
  end

  def test_calling_with_new_and_call
    operation = GreetUserOperation.new(name: "David")
    result = operation.call
    assert_equal "Hello, David!", result
  end

  # From defining-operations.md - Lifecycle hooks
  class OperationWithHooks < TypedOperation::Base
    param :value, Integer

    attr_reader :prepare_called, :before_called, :after_called

    def prepare
      @prepare_called = true
    end

    def before_execute_operation
      @before_called = true
    end

    def perform
      value * 2
    end

    def after_execute_operation(result)
      @after_called = true
      result
    end
  end

  def test_lifecycle_hooks_execution_order
    operation = OperationWithHooks.new(value: 5)
    result = operation.call

    assert_equal 10, result
    assert operation.prepare_called
    assert operation.before_called
    assert operation.after_called
  end

  # From parameters.md - Coercion
  class CoerceOperation < TypedOperation::Base
    param :user_id, Integer, &:to_i

    def perform
      user_id
    end
  end

  def test_parameter_coercion
    result = CoerceOperation.call(user_id: "123")
    assert_equal 123, result
    assert_kind_of Integer, result
  end

  # From parameters.md - Array types
  class ArrayParamOperation < TypedOperation::Base
    include Literal::Types

    param :tags, _Array(String)

    def perform
      tags
    end
  end

  def test_array_parameter_validation
    result = ArrayParamOperation.call(tags: ["ruby", "rails"])
    assert_equal ["ruby", "rails"], result
  end

  def test_array_parameter_type_validation
    assert_raises Literal::TypeError do
      ArrayParamOperation.call(tags: [1, 2, 3]) # Integers instead of Strings
    end
  end
end

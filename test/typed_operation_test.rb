# frozen_string_literal: true

require "test_helper"
require "dry/monads"

class TypedOperationTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert TypedOperation::VERSION
  end

  class TestOperation < ::TypedOperation::Base
    include Dry::Monads[:result]

    param :foo, String
    param :bar, String
    param :baz, String do |value|
      value.to_s
    end

    param :with_default, String, default: "qux"
    param :can_be_nil, Integer, allow_nil: true
    param :can_also_be_nil, TypedOperation::Base, default: nil

    def prepare
      @local_var = 123
    end

    def call
      Success("It worked!")
    end
  end

  def test_prepared
    prepared = TestOperation.with(foo: "1").with(bar: "2", baz: "3")
    assert_instance_of TypedOperation::Prepared, prepared
  end

  def test_operation_attributes_are_set
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_equal "1", operation.foo
    assert_equal "2", operation.bar
    assert_equal "3", operation.baz
  end

  def test_operation_supports_default_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_equal "qux", operation.with_default
  end

  def test_operation_supports_nil_default_values
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_nil operation.can_also_be_nil
  end

  def test_operation_supports_nil_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_nil operation.can_be_nil
  end

  def test_operation_sets_nilable_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3", can_be_nil: 123)
    assert_equal 123, operation.can_be_nil
  end

  def test_operation_params_type_can_be_arbitrary_class
    some_instance = TestOperation.new(foo: "1", bar: "2", baz: "3")
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3", can_also_be_nil: some_instance)
    assert_equal some_instance, operation.can_also_be_nil
  end

  def test_operation_params_type_can_be_arbitrary_class_raises
    assert_raises(TypeError) { TestOperation.new(foo: "1", bar: "2", baz: "3", can_also_be_nil: Set.new) }
  end

  def test_operation_is_prepared
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_equal 123, operation.instance_variable_get(:@local_var)
  end

  def test_operation_success
    result = TestOperation.call(foo: "1", bar: "2", baz: "3")
    assert_instance_of Dry::Monads::Result::Success, result
    assert_equal "It worked!", result.value!
  end

  def test_raises_on_invalid_param_type
    assert_raises(TypeError) { TestOperation.new(foo: 1, bar: "2", baz: "3") }
  end

  def test_partially_applied
    partially_applied = TestOperation.with(foo: "1").with(bar: "2")
    assert_instance_of TypedOperation::PartiallyApplied, partially_applied
  end

  def test_partially_applied_using_aliases
    partially_applied = TestOperation[foo: "1"].curry(bar: "2")
    assert_instance_of TypedOperation::PartiallyApplied, partially_applied
  end

  def test_prepared_call
    result = TestOperation.with(foo: "1").with(bar: "2").with(baz: "3").call
    assert_instance_of Dry::Monads::Result::Success, result
    assert_equal "It worked!", result.value!
  end

  def test_prepared_operation_returns_an_instance_of_the_operation_with_attributes_set
    operation = TestOperation.with(foo: "1").with(bar: "2").with(baz: 3).operation
    assert_instance_of TestOperation, operation
    assert_equal "1", operation.foo
  end

  def test_operation_invocation_as_proc
    partially_applied = TestOperation.with(foo: "1", bar: "2")
    ["1", "2", "3"].each do |baz|
      assert_equal Dry::Monads::Result::Success.new("It worked!"), partially_applied.call(baz: baz)
    end
  end

  def test_operation_invocation_with_missing_param
    partially_applied = TestOperation.with(foo: "1")
    assert_raises(TypedOperation::MissingParameterError) { partially_applied.call }
  end

  def test_missing_param_error_is_a_argument_error
    partially_applied = TestOperation.with(foo: "1")
    assert_raises(ArgumentError) { partially_applied.call }
  end

  def test_operation_creation_with_missing_param
    assert_raises(ArgumentError) { TestOperation.new(foo: "1") }
  end
end

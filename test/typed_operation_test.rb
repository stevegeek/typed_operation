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
    param :baz, String, convert: true

    param :with_default, String, default: "qux"
    param :can_be_nil, Integer, allow_nil: true

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

  def test_operation_supports_nil_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_nil operation.can_be_nil
  end

  def test_operation_sets_nilable_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3", can_be_nil: 123)
    assert_equal 123, operation.can_be_nil
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

  def test_operation_instance_supports_pattern_matching_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
    assert_equal ["1", "2", "3", "qux"], operation.deconstruct
    assert_equal({foo: "1", bar: "2", baz: "3", with_default: "qux"}, operation.deconstruct_keys(%i[foo bar baz]))
    case operation
    in TestOperation[foo: foo, with_default: default, **rest]
      assert_equal "1", foo
      assert_equal "qux", default
      assert_equal({bar: "2", baz: "3"}, rest)
    else
      raise "Pattern match failed"
    end
    case operation
    in String => foo, String => bar, String => baz, String => with_default
      assert_equal "1", foo
      assert_equal "2", bar
      assert_equal "3", baz
      assert_equal "qux", with_default
    else
      raise "Pattern match failed"
    end
  end

  def test_operation_partially_applied_supports_pattern_matching_currently_applied_params
    partially_applied = TestOperation.with(foo: "1", bar: "2")
    case partially_applied
    in TypedOperation::PartiallyApplied[foo: foo, bar: bar, **rest]
      assert_equal "1", foo
      assert_equal "2", bar
      assert_equal({}, rest)
    else
      raise "Pattern match failed"
    end
    case partially_applied
    in String => foo, String => bar
      assert_equal "1", foo
      assert_equal "2", bar
    else
      raise "Pattern match failed"
    end
  end

  def test_operation_prepared_supports_pattern_matching_currently_applied_params
    prepared = TestOperation.with(foo: "1", bar: "2", baz: "3")
    case prepared
    in TypedOperation::Prepared[foo: foo, bar: bar, **rest]
      assert_equal "1", foo
      assert_equal "2", bar
      assert_equal({baz: "3"}, rest)
    else
      raise "Pattern match failed"
    end
    case prepared
    in String => foo, String => bar, String => baz
      assert_equal "1", foo
      assert_equal "2", bar
      assert_equal "3", baz
    else
      raise "Pattern match failed"
    end
  end
end

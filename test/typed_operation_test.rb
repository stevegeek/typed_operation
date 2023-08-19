# frozen_string_literal: true

require "test_helper"
require "dry/monads"

class TypedOperationTest < ActiveSupport::TestCase
  test "it has a version number" do
    assert TypedOperation::VERSION
  end

  class TestPositionalOperation < ::TypedOperation::Base
    param :first, String, positional: true
    param :second, String, allow_nil: true, positional: true

    def call
      if second
        "#{first}/#{second}"
      else
        "#{first}!"
      end
    end
  end

  class TestKeywordAndPositionalOperation < ::TypedOperation::Base
    positional :pos1, String
    positional :pos2, String, default: "pos2"
    named :kw1, String
    named :kw2, String, default: "kw2"

    def call
      "#{pos1}/#{pos2}/#{kw1}/#{kw2}"
    end
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

  def test_class_method_positional_parameters
    assert_equal %i[first second], TestPositionalOperation.positional_parameters
    assert_equal %i[pos1 pos2], TestKeywordAndPositionalOperation.positional_parameters
  end

  def test_class_method_keyword_parameters
    assert_equal [], TestPositionalOperation.keyword_parameters
    assert_equal %i[kw1 kw2], TestKeywordAndPositionalOperation.keyword_parameters
  end

  def test_class_method_required_positional_parameters
    assert_equal %i[first], TestPositionalOperation.required_positional_parameters
    assert_equal %i[pos1], TestKeywordAndPositionalOperation.required_positional_parameters
  end

  def test_class_method_required_keyword_parameters
    assert_equal [], TestPositionalOperation.required_keyword_parameters
    assert_equal %i[kw1], TestKeywordAndPositionalOperation.required_keyword_parameters
  end

  def test_class_method_operation_key
    assert_equal :"typed_operation_test/test_operation", TestOperation.operation_key
  end

  def test_operation_acts_as_proc
    assert_equal ["first!", "second!"], ["first", "second"].map(&TestPositionalOperation)
  end

  def test_operation_acts_as_proc_on_partially_applied
    curried_operation = TestPositionalOperation.with("first")
    assert_equal ["first/second", "first/third"], ["second", "third"].map(&curried_operation)
  end

  def test_operation_positional_args
    operation = TestPositionalOperation.new("first", "second")
    assert_equal "first", operation.first
    assert_equal "second", operation.second
  end

  def test_operation_optional_positional_args
    operation = TestPositionalOperation.new("first")
    assert_equal "first!", operation.call
  end

  def test_operation_mix_args
    operation = TestKeywordAndPositionalOperation.new("first", "second", kw1: "foo", kw2: "bar")
    assert_equal "first/second/foo/bar", operation.call
  end

  def test_operation_optional_mix_args
    operation = TestKeywordAndPositionalOperation.new("first", kw1: "bar")
    assert_equal "first/pos2/bar/kw2", operation.call
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

  def test_operation_instance_support_pattern_matching_on_mixed_arguments
    operation = TestKeywordAndPositionalOperation.new("first", "second", kw1: "foo", kw2: "bar")
    assert_equal ["first", "second", "foo", "bar"], operation.deconstruct
    assert_equal({pos1: "first", pos2: "second", kw1: "foo", kw2: "bar"}, operation.deconstruct_keys(nil))
    assert_equal({pos1: "first", kw2: "bar"}, operation.deconstruct_keys(%i[pos1 kw2]))
  end

  def test_partially_applied_operation_support_pattern_matching_on_mixed_arguments
    operation = TestKeywordAndPositionalOperation.with("first", "second", kw2: "bar")
    assert_equal ["first", "second", "bar"], operation.deconstruct
    assert_equal({pos1: "first", pos2: "second", kw2: "bar"}, operation.deconstruct_keys(nil))
    assert_equal({pos2: "second", kw2: "bar"}, operation.deconstruct_keys(%i[pos2 kw2]))
  end

  def test_operation_instance_supports_pattern_matching_params
    operation = TestOperation.new(foo: "1", bar: "2", baz: "3", can_be_nil: 5)
    assert_equal ["1", "2", "3", "qux", 5, nil], operation.deconstruct
    assert_equal({foo: "1", bar: "2", baz: "3", with_default: "qux", can_be_nil: 5, can_also_be_nil: nil}, operation.deconstruct_keys(nil))
    assert_equal({foo: "1", can_be_nil: 5}, operation.deconstruct_keys(%i[foo can_be_nil]))
    case operation
    in TestOperation[foo: foo, with_default: default, **rest]
      assert_equal "1", foo
      assert_equal "qux", default
      assert_equal({bar: "2", baz: "3", can_be_nil: 5, can_also_be_nil: nil}, rest)
    else
      raise Minitest::UnexpectedError, "Pattern match failed"
    end
    case operation
    in String => foo, String => bar, String => baz, String => with_default, Integer => can_be_nil, NilClass => can_also_be_nil
      assert_equal "1", foo
      assert_equal "2", bar
      assert_equal "3", baz
      assert_equal "qux", with_default
      assert_equal 5, can_be_nil
      assert_nil can_also_be_nil
    else
      raise Minitest::UnexpectedError, "Pattern match failed"
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
      raise Minitest::UnexpectedError, "Pattern match failed"
    end
    case partially_applied
    in String => foo, String => bar
      assert_equal "1", foo
      assert_equal "2", bar
    else
      raise Minitest::UnexpectedError, "Pattern match failed"
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
      raise Minitest::UnexpectedError, "Pattern match failed"
    end
    case prepared
    in String => foo, String => bar, String => baz
      assert_equal "1", foo
      assert_equal "2", bar
      assert_equal "3", baz
    else
      raise Minitest::UnexpectedError, "Pattern match failed"
    end
  end
end

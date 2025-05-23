# frozen_string_literal: true

require "test_helper"
require "dry-monads"

module TypedOperation
  class BaseTest < Minitest::Test
    class TestPositionalOperation < ::TypedOperation::Base
      param :first, String, positional: true
      param :second, String, optional: true, positional: true, &:to_s

      def before_execute_operation
        @before_was_called = true
        super
      end

      def after_execute_operation(_retval)
        @after_was_called = true
        super
      end

      def perform
        if second
          "#{first}/#{second}"
        else
          "#{first}!"
        end
      end
    end

    class TestKeywordAndPositionalOperation < ::TypedOperation::Base
      param :pos1, String, positional: true
      param :pos2, String, default: "pos2", positional: true
      param :kw1, String
      param :kw2, String, default: "kw2"

      def perform
        "#{pos1}/#{pos2}/#{kw1}/#{kw2}"
      end
    end

    class TestAlternativeDslOperation < ::TypedOperation::Base
      positional_param :pos1, String
      positional_param :pos2, String, default: "pos2"
      positional_param :pos3, optional(String)
      named_param :kw1, String
      named_param :kw2, String, default: "kw2"
      named_param :kw3, optional(String)

      def perform
        "#{pos1}/#{pos2}/#{pos3}/#{kw1}/#{kw2}/#{kw3}"
      end
    end

    class TestOperation < ::TypedOperation::Base
      param :foo, String
      param :bar, String
      param :baz, String do |value|
        value.to_s
      end

      param :with_default, String, default: "qux"
      param :can_be_nil, Integer, optional: true
      param :can_also_be_nil, TypedOperation::Base, default: nil

      def prepare
        @local_var = 123
      end

      def perform
        "It worked, (#{foo}/#{bar}/#{baz}/#{with_default}/#{can_be_nil}/#{can_also_be_nil})"
      end
    end

    class TestCurryOperation < ::TypedOperation::Base
      param :pos1, String, positional: true
      param :pos2, String, positional: true
      param :pos3, optional(String), positional: true
      param :kw1, String
      param :kw2, String
      param :kw3, optional(String)

      def perform
        "#{pos1}/#{pos2}/#{pos3}/#{kw1}/#{kw2}/#{kw3}"
      end
    end

    class MyMutableOperation < ::TypedOperation::Base
      param :my_hash, Hash, default: -> { {} }
    end

    class TestInvalidOperation < ::TypedOperation::Base
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

    def test_class_method_optional_positional_parameters
      assert_equal %i[second], TestPositionalOperation.optional_positional_parameters
      assert_equal %i[pos2], TestKeywordAndPositionalOperation.optional_positional_parameters
    end

    def test_class_method_optional_keyword_parameters
      assert_equal [], TestPositionalOperation.optional_keyword_parameters
      assert_equal %i[kw2], TestKeywordAndPositionalOperation.optional_keyword_parameters
    end

    def test_positional_param_coercion_block
      operation = TestPositionalOperation.new("first", 123)
      assert_equal "first/123", operation.call
    end

    def test_optional_param_coercion
      operation = TestPositionalOperation.new("first")
      assert_equal "first!", operation.call
    end

    def test_operation_is_callable
      operation = TestPositionalOperation.new("first", 123)
      assert_equal "first/123", operation.call
    end

    def test_operation_call_executes_operation_and_before_and_after_callbacks
      operation = TestPositionalOperation.new("first", 123)
      assert_equal "first/123", operation.call
      assert operation.instance_variable_get(:@before_was_called)
      assert operation.instance_variable_get(:@after_was_called)
    end

    def test_operation_execute_operation_and_runs_callbacks
      operation = TestPositionalOperation.new("first", 123)
      assert_equal "first/123", operation.execute_operation
      assert operation.instance_variable_get(:@before_was_called)
      assert operation.instance_variable_get(:@after_was_called)
    end

    def test_operation_acts_as_proc
      assert_equal ["first!", "second!"], ["first", "second"].map(&TestPositionalOperation)
    end

    def test_operation_raises_on_invalid_positional_params
      assert_raises do
        Class.new(::TypedOperation::Base) do
          # This is invalid, because positional params can't be optional before required ones
          positional_param :first, String, optional: true
          positional_param :second, String
        end
      end
    end

    def test_operation_raises_on_invalid_positional_params_using_optional
      assert_raises(::TypedOperation::ParameterError) do
        Class.new(::TypedOperation::Base) do
          # This is invalid, because positional params can't be optional before required ones
          positional_param :first, optional(String)
          positional_param :second, Literal::Types::NilableType.new(String)
          positional_param :third, String # required after optional is not possible
        end
      end
    end

    def test_operation_acts_as_proc_on_partially_applied
      curried_operation = TestPositionalOperation.with("first")
      assert_equal ["first/second", "first/third"], ["second", "third"].map(&curried_operation)
    end

    def test_partially_applied_as_proc_with_mixed_args
      operation = TestAlternativeDslOperation.with("first", kw1: "bar", kw3: "123")
      assert_equal ["first/1//bar/kw2/123", "first/2//bar/kw2/123", "first/3//bar/kw2/123"], ["1", "2", "3"].map(&operation)
    end

    def test_operation_to_proc
      operation = TestPositionalOperation.new("first")
      assert_equal "first!", operation.to_proc.call
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

    def test_positional_arg_count_must_make_sense
      assert_raises(ArgumentError) { TestPositionalOperation.new("first", "second", "third") }
    end

    def test_positional_arg_count_must_make_sense_when_partial_application
      assert_raises(ArgumentError) { TestPositionalOperation.with("first", "second", "third") }
    end

    def test_operation_mix_args
      operation = TestKeywordAndPositionalOperation.new("first", "second", kw1: "foo", kw2: "bar")
      assert_equal "first/second/foo/bar", operation.call
    end

    def test_operation_optional_mix_args
      operation = TestKeywordAndPositionalOperation.new("first", kw1: "bar")
      assert_equal "first/pos2/bar/kw2", operation.call
    end

    def test_operation_alternative_dsl
      operation = TestAlternativeDslOperation.new("first", kw1: "bar", kw3: "123")
      assert_equal "first/pos2//bar/kw2/123", operation.call
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

    def test_operation_invocation
      assert_equal "It worked, (1/2/3/qux//)", TestOperation.call(foo: "1", bar: "2", baz: "3")
    end

    def test_raises_on_invalid_param_type
      assert_raises(TypeError) { TestOperation.new(foo: 1, bar: "2", baz: "3") }
    end

    def test_partially_applied
      partially_applied = TestOperation.with(foo: "1").with(bar: "2")
      assert_instance_of TypedOperation::PartiallyApplied, partially_applied
    end

    def test_partially_applied_using_aliases
      partially_applied = TestOperation[foo: "1"]
      assert_instance_of TypedOperation::PartiallyApplied, partially_applied
    end

    def test_prepared_call
      result = TestOperation.with(foo: "1").with(bar: "2").with(baz: "3").call
      assert_equal "It worked, (1/2/3/qux//)", result
    end

    def test_prepared_operation_returns_an_instance_of_the_operation_with_attributes_set
      operation = TestOperation.with(foo: "1").with(bar: "2").with(baz: 3).operation
      assert_instance_of TestOperation, operation
      assert_equal "1", operation.foo
    end

    def test_partially_applied_operation_raises_on_operation
      assert_raises(TypedOperation::MissingParameterError) { TestOperation.with(foo: "1").operation }
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
        raise Minitest::Assertion, "Pattern match failed"
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
        raise Minitest::Assertion, "Pattern match failed"
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
        raise Minitest::Assertion, "Pattern match failed"
      end
      case partially_applied
      in String => foo, String => bar
        assert_equal "1", foo
        assert_equal "2", bar
      else
        raise Minitest::Assertion, "Pattern match failed"
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
        raise Minitest::Assertion, "Pattern match failed"
      end
      case prepared
      in String => foo, String => bar, String => baz
        assert_equal "1", foo
        assert_equal "2", bar
        assert_equal "3", baz
      else
        raise Minitest::Assertion, "Pattern match failed"
      end
    end

    def test_raises_when_operation_has_no_perform_method_defined
      error = assert_raises(::TypedOperation::InvalidOperationError) { TestInvalidOperation.call }
      assert_equal "Operation TypedOperation::BaseTest::TestInvalidOperation does not implement #perform", error.message
    end

    def test_operation_of_one_required_param_can_curry
      curried_operation = TestPositionalOperation.curry
      assert_instance_of TypedOperation::Curried, curried_operation
      assert_equal ["one!", "two!"], ["one", "two"].map(&curried_operation)
    end

    def test_operation_of_multliple_required_params_can_curry
      curried_operation = TestOperation.curry
      res = ["1", "2", 3].reduce(curried_operation) { |curried, arg| curried.call(arg) }
      assert_equal "It worked, (1/2/3/qux//)", res
    end

    def test_operation_can_be_partially_applied_then_curry
      partially_applied = TestCurryOperation.with("a", kw2: "e", kw3: "f")
      curried_operation = partially_applied.curry
      assert_instance_of TypedOperation::Curried, curried_operation
      assert_equal "a/b//d/e/f", curried_operation.call("b").call("d")
    end

    def test_operation_instance_can_be_copied_using_dup
      operation = TestKeywordAndPositionalOperation.new("1", "2", kw1: "1", kw2: "2")
      operation2 = operation.dup
      assert_equal "1/2/1/2", operation2.call
    end

    def test_operation_should_not_freeze_arguments
      operation = MyMutableOperation.new(my_hash: {a: 1})
      refute operation.my_hash.frozen?
      operation.my_hash[:b] = 2
      assert_equal({a: 1, b: 2}, operation.my_hash)
    end

    def test_with_dry_maybe_monad_partially_apply_then_curry
      operation_class = Class.new(::TypedOperation::Base) do
        positional_param :v1, Integer
        positional_param :v2, Integer

        def perform
          ::Dry::Monads::Maybe(v1 + v2)
        end
      end

      operation = operation_class.with(1)
      operation2 = operation_class.with(3)
      m = ::Dry::Monads::Maybe::Some.new(2)
      assert_equal m.bind(&operation.curry).bind(&operation2.curry), Dry::Monads::Maybe::Some.new(6)
      m = Dry::Monads::Maybe::None.instance
      assert_equal m.bind(&operation.curry).bind(&operation2.curry), Dry::Monads::Maybe::None.instance
    end

    def test_can_dup
      operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
      operation2 = operation.dup
      assert_equal "1", operation2.foo
      assert_equal "2", operation2.bar
      assert_equal "3", operation2.baz
    end

    def test_not_frozen
      operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
      refute operation.frozen?
    end

    def test_cannot_write_property
      operation = TestOperation.new(foo: "1", bar: "2", baz: "3")
      assert_raises do
        operation.foo = 2
      end
    end
  end
end

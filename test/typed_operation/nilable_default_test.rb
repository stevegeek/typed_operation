# frozen_string_literal: true

require "test_helper"

module TypedOperation
  class NilableDefaultTest < Minitest::Test
    class TestNilableWithDefault < ::TypedOperation::Base
      param :name, _Nilable(String), default: "foo"

      def perform
        name
      end
    end

    class TestOptionalWithDefault < ::TypedOperation::Base
      param :name, String, optional: true, default: "bar"

      def perform
        name
      end
    end

    class TestOptionalHelperWithNilDefault < ::TypedOperation::Base
      param :at, optional(Time), default: nil

      def perform
        at
      end
    end

    def test_nilable_with_explicit_default
      result = TestNilableWithDefault.call
      assert_equal "foo", result
    end

    def test_optional_with_explicit_default
      result = TestOptionalWithDefault.call
      assert_equal "bar", result
    end

    def test_nilable_can_be_set_to_nil
      result = TestNilableWithDefault.call(name: nil)
      assert_nil result
    end

    def test_optional_can_be_set_to_nil
      result = TestOptionalWithDefault.call(name: nil)
      assert_nil result
    end

    def test_optional_helper_with_nil_default_loads
      assert_nil TestOptionalHelperWithNilDefault.call
    end

    def test_optional_helper_with_nil_default_accepts_value
      now = Time.now
      assert_equal now, TestOptionalHelperWithNilDefault.call(at: now)
    end
  end
end

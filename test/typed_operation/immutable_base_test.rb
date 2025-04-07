# frozen_string_literal: true

require "test_helper"

module TypedOperation
  class ImmutableBaseTest < Minitest::Test
    class MyImmutableOperation < ::TypedOperation::ImmutableBase
      param :my_hash, Hash, default: -> { {} }
    end

    def test_immutable_operation_should_be_frozen
      operation = MyImmutableOperation.new(my_hash: {a: 1})
      assert operation.frozen?
      assert_raises(RuntimeError) { operation.instance_variable_set(:@my_hash, {}) }
    end
  end
end

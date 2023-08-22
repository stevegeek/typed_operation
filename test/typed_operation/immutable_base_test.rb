# frozen_string_literal: true

require "test_helper"

module TypedOperation
  class ImmutableBaseTest < Minitest::Test
    class MyImmutableOperation < ::TypedOperation::ImmutableBase
      param :my_hash, Hash, default: -> { {} }
    end

    def test_immutable_operation_should_freeze_arguments
      operation = MyImmutableOperation.new(my_hash: {a: 1})
      assert operation.my_hash.frozen?
      assert_raises(RuntimeError) { operation.my_hash[:b] = 2 }
    end
  end
end

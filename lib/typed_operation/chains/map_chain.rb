# frozen_string_literal: true

module TypedOperation
  # Functor map chain created by .transform
  # Like SequenceChain but auto-wraps the block's return value in Success.
  # Short-circuits on failure.
  class MapChain < SequenceChain
    def call(...)
      result = @left.call(...)
      return result if result.failure?

      result.fmap { |value| @right.call(value) }
    end
  end
end

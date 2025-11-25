# frozen_string_literal: true

module TypedOperation
  # Sequential composition chain created by .then
  # Passes the success value from the left operation to the right operation.
  # Short-circuits on failure.
  class SequenceChain < ChainedOperation
    def call(...)
      result = @left.call(...)
      return result if result.failure?

      @right.call(result.value!)
    end
  end
end

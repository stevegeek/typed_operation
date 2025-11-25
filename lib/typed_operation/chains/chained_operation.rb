# frozen_string_literal: true

module TypedOperation
  # Base class for operation chains.
  #
  # Values flow through chains as-is - no implicit splatting.
  # If you need to convert a value to kwargs for the next operation,
  # use .and_then { |v| NextOp.call(**v) } or .transform to reshape first.
  class ChainedOperation
    include Operations::Composition

    def initialize(left, right)
      @left = left
      @right = right
    end

    def call(...)
      raise NotImplementedError, "Subclasses must implement #call"
    end
  end
end

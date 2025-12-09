# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Base class for operation chains.
  #
  # Values flow through chains as-is - no implicit splatting.
  # If you need to convert a value to kwargs for the next operation,
  # use .then_passes { |v| NextOp.call(**v) } or .transform to reshape first.
  class ChainedOperation
    include Operations::Composition

    # @rbs @left: _Callable
    # @rbs @right: _Callable

    #: (_Callable, _Callable) -> void
    def initialize(left, right)
      @left = left
      @right = right
    end

    #: (*untyped, **untyped) -> _Result[untyped, untyped]
    def call(...)
      raise NotImplementedError, "Subclasses must implement #call"
    end
  end
end

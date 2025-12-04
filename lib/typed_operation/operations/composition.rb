# frozen_string_literal: true

module TypedOperation
  module Operations
    # Provides composition methods for chaining operations together.
    # Included in operation classes and composed operations (ChainedOperation, Pipeline).
    module Composition
      # Smart sequential composition with context accumulation.
      # - Accumulates results into a context hash across chain steps
      # - Introspects next operation's params and extracts from context
      # - Extra kwargs are merged in (sugar for .with)
      # Raises if operation has mixed positional and keyword params.
      def then(operation = nil, **extra_kwargs, &block)
        SmartChain.new(self, operation || block, extra_kwargs)
      end

      # Spreads the context as **kwargs to the next operation.
      #: (?untyped) ?{ (untyped) -> untyped } -> SplatChain
      def then_spreads(operation = nil, &block)
        SplatChain.new(self, operation || block)
      end

      # Passes the context as a single positional argument to the next operation.
      #: (?untyped) ?{ (untyped) -> untyped } -> SequenceChain
      def then_passes(operation = nil, &block)
        SequenceChain.new(self, operation || block)
      end


      # Functor mapping - transform success values without changing the monad.
      # Block receives unwrapped value and return is automatically wrapped in Success.
      def transform(&block)
        MapChain.new(self, block)
      end

      # Fallback handling - provide alternative when main operation fails.
      # Only called if the left side returns Failure.
      def or_else(fallback = nil, &block)
        FallbackChain.new(self, fallback || block)
      end
    end
  end
end

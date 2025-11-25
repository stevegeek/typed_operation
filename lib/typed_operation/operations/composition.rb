# frozen_string_literal: true

module TypedOperation
  module Operations
    # Provides composition methods for chaining operations together.
    # Included in operation classes and composed operations (ChainedOperation, Pipeline).
    module Composition
      # Smart sequential composition - introspects the next operation's signature.
      # If it has keyword params → splats the value as **kwargs
      # If it has a single positional param → passes value as-is
      # Raises if operation has mixed positional and keyword params.
      def then(operation = nil, &block)
        SmartChain.new(self, operation || block)
      end

      # Explicit kwargs splatting - always splats value as **kwargs.
      def then_splat(operation = nil, &block)
        SplatChain.new(self, operation || block)
      end

      # Explicit value passing - always passes value as single positional arg.
      def then_value(operation = nil, &block)
        SequenceChain.new(self, operation || block)
      end

      # Monadic bind - explicit chaining with blocks for custom logic.
      # Block receives unwrapped success value and MUST return a Result.
      def and_then(&block)
        SequenceChain.new(self, block)
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

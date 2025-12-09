# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  module Operations
    # Provides composition methods for chaining operations together.
    # Included in operation classes and composed operations (ChainedOperation, Pipeline).
    module Composition
      # Smart sequential composition with context accumulation.
      # Auto-detects whether to spread kwargs or pass as single value.
      #: (?(singleton(Base) | Proc), **untyped) ?{ (untyped) -> untyped } -> SmartChain
      def then(operation = nil, **extra_kwargs, &block)
        SmartChain.new(self, operation || block, extra_kwargs)
      end

      # Spreads the context as **kwargs to the next operation.
      #: (?(singleton(Base) | Proc)) ?{ (untyped) -> untyped } -> SplatChain
      def then_spreads(operation = nil, &block)
        SplatChain.new(self, operation || block)
      end

      # Passes the context as a single positional argument to the next operation.
      #: (?(singleton(Base) | Proc)) ?{ (untyped) -> untyped } -> SequenceChain
      def then_passes(operation = nil, &block)
        SequenceChain.new(self, operation || block)
      end

      # Transforms the success value, replacing the context entirely.
      #: () { (untyped) -> untyped } -> MapChain
      def transform(&block)
        MapChain.new(self, block)
      end

      # Provides a fallback when the operation fails.
      #: (?(singleton(Base) | Proc)) ?{ (untyped) -> untyped } -> FallbackChain
      def or_else(fallback = nil, &block)
        FallbackChain.new(self, fallback || block)
      end
    end
  end
end

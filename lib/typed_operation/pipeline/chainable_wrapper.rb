# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  class Pipeline
    # Wrapper that exposes full Composition methods while delegating to Pipeline.
    class ChainableWrapper
      include Operations::Composition

      # @rbs @pipeline: Pipeline

      #: (Pipeline) -> void
      def initialize(pipeline)
        @pipeline = pipeline
      end

      #: (*untyped, **untyped) -> untyped
      def call(...)
        @pipeline.call(...)
      end
    end
  end
end

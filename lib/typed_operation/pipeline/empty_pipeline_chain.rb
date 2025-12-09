# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  class Pipeline
    # Handles empty pipelines - just passes through input as Success.
    class EmptyPipelineChain
      include Result::Mixin

      #: (*untyped, **untyped) -> untyped
      def call(*args, **kwargs)
        value = if kwargs.any?
          kwargs
        elsif args.size == 1
          args.first
        elsif args.any?
          args
        else
          {}
        end
        Success(value)
      end
    end
  end
end

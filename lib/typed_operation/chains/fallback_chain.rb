# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Fallback chain created by .or_else
  # Calls the fallback only when the left operation fails.
  # Passes through success unchanged.
  #
  # For blocks: passes the failure value.
  # For operations: passes the original call arguments (so fallback can retry).
  class FallbackChain < ChainedOperation
    #: (*untyped, **untyped) -> _Result[untyped, untyped]
    def call(*args, **kwargs)
      result = @left.call(*args, **kwargs)
      return result if result.success?

      if Instrumentation.tracing?
        Instrumentation.set_chain_context(
          pass_mode: :fallback,
          extracted_params: nil,
          fallback_used: true
        )
      end

      if @right.is_a?(Proc)
        @right.call(result.failure)
      else
        @right.call(*args, **kwargs)
      end
    end
  end
end

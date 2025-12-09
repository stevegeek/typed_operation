# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Kwargs spreading chain created by .then_spreads
  # Always splats the full context as **kwargs to the next operation.
  # Accumulates result into context.
  class SplatChain < ChainedOperation
    include Result::Mixin

    #: (*untyped, **untyped) -> _Result[untyped, untyped]
    def call(...)
      result = @left.call(...)
      return result if result.failure?

      left_value = result.value!
      context = to_context(left_value)

      right_result = @right.call(**context)
      return right_result if right_result.failure?

      # Merge right's output into context
      right_value = right_result.value!
      merged = merge_into_context(context, right_value)

      Success(merged)
    end

    private

    #: (untyped) -> Hash[Symbol, untyped]
    def to_context(value)
      if value.respond_to?(:to_hash)
        value.to_hash
      elsif value.respond_to?(:to_h)
        value.to_h
      else
        raise ArgumentError, "Cannot splat #{value.class} as kwargs - must respond to #to_hash or #to_h"
      end
    end

    #: (Hash[Symbol, untyped], untyped) -> Hash[Symbol, untyped]
    def merge_into_context(context, value)
      if value.respond_to?(:to_hash)
        context.merge(value.to_hash)
      elsif value.respond_to?(:to_h)
        context.merge(value.to_h)
      else
        context.merge(_value: value)
      end
    end
  end
end

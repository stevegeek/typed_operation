# frozen_string_literal: true

module TypedOperation
  # Kwargs splatting chain created by .then_splat
  # Always splats the success value as **kwargs to the next operation.
  class SplatChain < ChainedOperation
    def call(...)
      result = @left.call(...)
      return result if result.failure?

      @right.call(**to_kwargs(result.value!))
    end

    private

    def to_kwargs(value)
      if value.respond_to?(:to_hash)
        value.to_hash
      elsif value.respond_to?(:to_h)
        value.to_h
      else
        raise ArgumentError, "Cannot splat #{value.class} as kwargs - must respond to #to_hash or #to_h"
      end
    end
  end
end

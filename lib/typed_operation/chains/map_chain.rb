# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Functor map chain created by .transform
  # Block receives context, return value replaces context (wrapped in Success).
  # Short-circuits on failure.
  class MapChain < ChainedOperation
    include Result::Mixin

    #: (*untyped, **untyped) -> _Result[untyped, untyped]
    def call(...)
      result = @left.call(...)
      return result if result.failure?

      left_value = result.value!
      context = to_context(left_value)

      # Transform replaces context entirely (no merge)
      transformed = @right.call(context)
      Success(transformed)
    end

    private

    #: (untyped) -> Hash[Symbol, untyped]
    def to_context(value)
      if value.respond_to?(:to_hash)
        value.to_hash
      elsif value.respond_to?(:to_h)
        value.to_h
      else
        {_value: value}
      end
    end
  end
end

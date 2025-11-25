# frozen_string_literal: true

module TypedOperation
  # Smart chain created by .then
  # Introspects the target operation to determine whether to splat kwargs or pass value.
  class SmartChain < ChainedOperation
    def initialize(left, right)
      super
      @splat = splat?(right)
    end

    def call(...)
      result = @left.call(...)
      return result if result.failure?

      value = result.value!
      if @splat
        @right.call(**to_kwargs(value))
      else
        @right.call(value)
      end
    end

    private

    def splat?(operation)
      op_class = extract_operation_class(operation)
      return false unless op_class.respond_to?(:positional_parameters)

      positional = op_class.positional_parameters
      keywords = op_class.keyword_parameters

      if positional.any? && keywords.any?
        raise ArgumentError,
          "Cannot chain to operation with both positional and keyword params. Use .transform to adapt."
      end

      keywords.any?
    end

    def extract_operation_class(operation)
      case operation
      when Class then operation
      when TypedOperation::PartiallyApplied then operation.operation_class
      when Proc then nil
      else operation.class
      end
    end

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

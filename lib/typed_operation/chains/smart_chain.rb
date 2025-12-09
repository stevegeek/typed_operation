# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Smart chain created by .then
  # Accumulates context across chain steps and extracts required params for each operation.
  class SmartChain < ChainedOperation
    def initialize(left, right, extra_kwargs = {})
      super(left, right)
      @extra_kwargs = extra_kwargs
      @uses_kwargs = uses_kwargs?(right)
      @required_params = extract_required_params(right)
      @prefilled_params = extract_prefilled_params(right)
    end

    def call(*args, **kwargs)
      # Execute left side
      result = @left.call(*args, **kwargs)
      return result if result.failure?

      # Build context from left's result
      left_value = result.value!
      context = to_context(left_value)

      # Call right side with appropriate params
      right_result = call_right(context)
      return right_result if right_result.failure?

      # Merge right's output into context
      right_value = right_result.value!
      merged = merge_into_context(context, right_value)

      Success(merged)
    end

    private

    def to_context(value)
      if value.respond_to?(:to_hash)
        value.to_hash
      elsif value.respond_to?(:to_h)
        value.to_h
      else
        {_value: value}
      end
    end

    def merge_into_context(context, value)
      if value.respond_to?(:to_hash)
        context.merge(value.to_hash)
      elsif value.respond_to?(:to_h)
        context.merge(value.to_h)
      else
        context.merge(_value: value)
      end
    end

    def call_right(context)
      if @uses_kwargs
        # Extract only the params the operation needs from context
        extracted = extract_from_context(context, @required_params)

        # Merge: extracted from context < prefilled from .with < extra kwargs from .then
        call_kwargs = extracted.merge(@prefilled_params).merge(@extra_kwargs)

        # Check for missing required params
        validate_required_params!(call_kwargs)

        @right.call(**call_kwargs)
      else
        # Positional param operation - pass full context
        if Instrumentation.tracing?
          Instrumentation.set_chain_context(
            pass_mode: :single_value,
            extracted_params: nil
          )
        end

        @right.call(context)
      end
    end

    def extract_from_context(context, params)
      params.each_with_object({}) do |key, hash|
        hash[key] = context[key] if context.key?(key)
      end
    end

    def validate_required_params!(kwargs)
      op_class = extract_operation_class(@right)
      return unless op_class.respond_to?(:required_keyword_parameters)

      required = op_class.required_keyword_parameters
      missing = required - kwargs.keys

      if missing.any?
        raise ArgumentError,
          "Missing required parameters for #{op_class.name}: #{missing.join(", ")}. " \
          "Available in context or provide via .with or .then(op, key: value)"
      end
    end

    def uses_kwargs?(operation)
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

    def extract_required_params(operation)
      op_class = extract_operation_class(operation)
      return [] unless op_class.respond_to?(:keyword_parameters)
      op_class.keyword_parameters
    end

    def extract_prefilled_params(operation)
      case operation
      when TypedOperation::PartiallyApplied
        operation.keyword_args
      else
        {}
      end
    end

    def extract_operation_class(operation)
      case operation
      when Class then operation
      when TypedOperation::PartiallyApplied then operation.operation_class
      when TypedOperation::ChainedOperation then extract_operation_class(operation.instance_variable_get(:@left))
      when Proc then nil
      else operation.class
      end
    end
  end
end

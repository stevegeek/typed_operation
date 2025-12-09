# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Utility module for resolving callable objects (operations, procs, chains)
  # and determining how to invoke them (kwargs vs positional).
  module CallableResolver
    #: (_Callable) -> untyped
    def extract_operation_class(operation)
      case operation
      when Class then operation
      when TypedOperation::PartiallyApplied then operation.operation_class
      when TypedOperation::ChainedOperation then extract_operation_class(operation.instance_variable_get(:@left))
      when Proc then nil
      else operation.class
      end
    end

    #: (_Callable) -> bool
    def uses_kwargs?(operation)
      op_class = extract_operation_class(operation)
      return false unless op_class.respond_to?(:positional_parameters)

      positional = op_class.positional_parameters
      keywords = op_class.keyword_parameters

      keywords.any? && positional.empty?
    end
  end
end

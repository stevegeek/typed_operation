# rbs_inline: enabled
# frozen_string_literal: true

module TypedOperation
  # Represents an operation with all required parameters provided and ready for execution.
  # Created when a PartiallyApplied operation receives its final required parameters.
  class Prepared < PartiallyApplied
    #: () -> TypedOperation::Base
    def operation
      operation_class.new(*@positional_args, **@keyword_args)
    end

    #: () -> true
    def prepared?
      true
    end

    #: () -> untyped
    def explain
      unless operation_class.respond_to?(:explain)
        raise InvalidOperationError, "#{operation_class.name} does not support .explain. Include TypedOperation::Explainable in your operation class."
      end
      operation_class.explain(*@positional_args, **@keyword_args)
    end
  end
end

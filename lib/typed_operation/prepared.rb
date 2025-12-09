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
  end
end

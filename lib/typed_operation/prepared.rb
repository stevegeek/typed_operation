# frozen_string_literal: true

module TypedOperation
  class Prepared < PartiallyApplied
    def operation
      operation_class.new(*@positional_args, **@keyword_args)
    end

    def prepared?
      true
    end
  end
end

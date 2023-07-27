# frozen_string_literal: true

module TypedOperation
  class Prepared < PartiallyApplied
    def operation
      operation_class.new(**@applied_args)
    end
  end
end

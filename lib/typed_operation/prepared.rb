# frozen_string_literal: true

module TypedOperation
  class Prepared < PartiallyApplied
    def operation
      @operation.new(**@applied_args)
    end
  end
end

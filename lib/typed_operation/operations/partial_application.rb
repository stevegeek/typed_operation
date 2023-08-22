# frozen_string_literal: true

module TypedOperation
  module Operations
    module PartialApplication
      def with(...)
        PartiallyApplied.new(self, ...).with
      end
      alias_method :[], :with

      def curry
        Curried.new(self)
      end
    end
  end
end
